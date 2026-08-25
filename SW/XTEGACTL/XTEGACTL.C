/* XTEGACTL - per-program hardware control for the PCXT-EGA core.
 *
 * Sets the machine up the way a program wants it before the program runs,
 * without walking the OSD.  Meant for a batch file next to a game:
 *
 *     XTEGACTL 4.77 adlib joy1=digital
 *     GAME.EXE
 *     XTEGACTL reset
 *
 * Everything here takes effect immediately.  Options the core only samples
 * while it is in reset - CPU type, the EGA monitor switches, the 2nd SD card
 * mapping - are deliberately absent: they describe the user's machine, not
 * the program, and the OSD says so when they are changed.
 *
 * Anything not named on the command line is left to the OSD, and the tool
 * rewrites the whole register file on every run, so a setting from an earlier
 * program never survives into the next one.  "reset" hands everything back.
 *
 * Build with Open Watcom:  wmake
 */

#include <stdio.h>
#include <conio.h>
#include <string.h>

#define VERSION         "1.0"

/* Port block.  See rtl/KFPC-XT/HDL/xtegactl.sv for why it lives at 8980h and
   not next to the retired 8888h port. */
#define P_SIG           0x8980
#define P_CPU           0x8981
#define P_EXP           0x8982
#define P_VID           0x8983
#define P_INP           0x8984
#define P_MIDI          0x8985

#define SIGNATURE       0x45    /* 'E' */

/* Every field reads 0 as "leave it to the OSD" and 1..N as the N choices, in
   the same order the OSD lists them. */
static unsigned char r_cpu, r_exp, r_vid, r_inp, r_midi;

static int _argc;
static char **_argv;
static int matched[64];

static int opt(char *name)
{
    int i;
    for (i = 1; i < _argc && i < 64; i++)
    {
        if (strcmpi(_argv[i], name) == 0)
        {
            matched[i] = 1;
            return 1;
        }
    }
    return 0;
}

/* Places `value` in the field `width` bits wide starting at `shift`. */
static void put(unsigned char *reg, int shift, int width, unsigned char value)
{
    unsigned char mask = (unsigned char)(((1 << width) - 1) << shift);
    *reg = (unsigned char)((*reg & ~mask) | ((value << shift) & mask));
}

static void usage(char *argv0)
{
    printf("XTEGACTL %s - per-program hardware control for PCXT-EGA\n\n", VERSION);
    printf("USAGE: %s [options]\n\n", argv0);
    printf("CPU        4.77  7.16  9.54  max\n");
    printf("           fake286  nofake286\n");
    printf("Audio      adlib  sbfm  noadlib\n");
    printf("           cms  nocms\n");
    printf("Memory     ems  noems       umb  noumb\n");
    printf("Video      vga13  novga13\n");
    printf("Input      joy1=analog|digital|off   joy2=analog|digital|off\n");
    printf("           swap  noswap      joysync  nojoysync\n");
    printf("MIDI       mt32  gm\n\n");
    printf("           reset       hand everything back to the OSD\n");
    printf("           status      show what is currently overridden\n\n");
    printf("Anything not named is left to the OSD. Settings are not cumulative:\n");
    printf("each run rewrites them all, so nothing carries over between programs.\n");
    printf("All of these apply at once; none of them need a machine reset.\n");
}

static char *choice(char *prefix)
{
    int i;
    int n = strlen(prefix);
    for (i = 1; i < _argc && i < 64; i++)
    {
        if (strnicmp(_argv[i], prefix, n) == 0)
        {
            matched[i] = 1;
            return _argv[i] + n;
        }
    }
    return NULL;
}

static int joystick(char *prefix, unsigned char *reg, int shift)
{
    char *v = choice(prefix);
    if (v == NULL) return 0;

    if (strcmpi(v, "analog") == 0)       put(reg, shift, 2, 1);
    else if (strcmpi(v, "digital") == 0) put(reg, shift, 2, 2);
    else if (strcmpi(v, "off") == 0)     put(reg, shift, 2, 3);
    else
    {
        printf("XTEGACTL: %s%s is not analog, digital or off\n", prefix, v);
        return -1;
    }
    return 0;
}

static void show(void)
{
    static char *speed[5] = { "OSD", "4.77MHz", "7.16MHz", "9.54MHz", "Max" };
    static char *onoff[4] = { "OSD", "off", "on", "-" };
    static char *opl[4]   = { "OSD", "Adlib 388h", "SB FM 388h/228h", "disabled" };
    static char *enab[4]  = { "OSD", "enabled", "disabled", "-" };
    static char *joy[4]   = { "OSD", "analog", "digital", "disabled" };
    static char *midi[4]  = { "OSD", "MT-32", "General MIDI", "-" };
    unsigned char s;

    r_cpu  = (unsigned char)inp(P_CPU);
    r_exp  = (unsigned char)inp(P_EXP);
    r_vid  = (unsigned char)inp(P_VID);
    r_inp  = (unsigned char)inp(P_INP);
    r_midi = (unsigned char)inp(P_MIDI);

    s = (unsigned char)(r_cpu & 0x07);
    if (s > 4) s = 0;

    printf("XTEGACTL %s - current overrides\n\n", VERSION);
    printf("  CPU speed      %s\n", speed[s]);
    printf("  Fake 286 FLAGS %s\n", onoff[(r_cpu >> 3) & 3]);
    printf("  OPL2           %s\n", opl[r_exp & 3]);
    printf("  C/MS audio     %s\n", enab[(r_exp >> 2) & 3]);
    printf("  EMS            %s\n", enab[(r_exp >> 4) & 3]);
    printf("  UMB            %s\n", enab[(r_exp >> 6) & 3]);
    printf("  VGA 13h+       %s\n", onoff[r_vid & 3]);
    printf("  Joystick 1     %s\n", joy[r_inp & 3]);
    printf("  Joystick 2     %s\n", joy[(r_inp >> 2) & 3]);
    printf("  Swap joysticks %s\n", onoff[(r_inp >> 4) & 3]);
    printf("  Joy CPU sync   %s\n", onoff[(r_inp >> 6) & 3]);
    printf("  MT32-pi mode   %s\n", midi[r_midi & 3]);
    printf("\n\"OSD\" means the menu setting is in force.\n");
}

int main(int argc, char **argv)
{
    char *argv0, *bs;
    int i;

    bs = strrchr(argv[0], '\\');
    argv0 = (bs == NULL) ? argv[0] : ++bs;

    if (argc < 2)
    {
        usage(argv0);
        return 1;
    }

    _argc = argc;
    _argv = argv;
    for (i = 0; i < 64; i++) matched[i] = 0;

    /* Refuse to write into the void.  The tool travels in the disk image and
       the RBF is updated separately, so it is entirely normal for someone to
       run a new XTEGACTL on a core that predates the port block. Without this
       check that would look exactly like the tool doing nothing at all. */
    if ((unsigned char)inp(P_SIG) != SIGNATURE)
    {
        printf("XTEGACTL: this core does not have the XTEGACTL port block.\n");
        printf("          Update the PCXT-EGA RBF and try again.\n");
        return 2;
    }

    if (opt("status"))
    {
        show();
        return 0;
    }

    r_cpu = r_exp = r_vid = r_inp = r_midi = 0;

    if (!opt("reset"))
    {
        if (opt("4.77") || opt("477")) put(&r_cpu, 0, 3, 1);
        else if (opt("7.16") || opt("716")) put(&r_cpu, 0, 3, 2);
        else if (opt("9.54") || opt("954")) put(&r_cpu, 0, 3, 3);
        else if (opt("max")) put(&r_cpu, 0, 3, 4);

        if (opt("nofake286")) put(&r_cpu, 3, 2, 1);
        else if (opt("fake286")) put(&r_cpu, 3, 2, 2);

        if (opt("adlib")) put(&r_exp, 0, 2, 1);
        else if (opt("sbfm")) put(&r_exp, 0, 2, 2);
        else if (opt("noadlib")) put(&r_exp, 0, 2, 3);

        if (opt("cms")) put(&r_exp, 2, 2, 1);
        else if (opt("nocms")) put(&r_exp, 2, 2, 2);

        if (opt("ems")) put(&r_exp, 4, 2, 1);
        else if (opt("noems")) put(&r_exp, 4, 2, 2);

        if (opt("umb")) put(&r_exp, 6, 2, 1);
        else if (opt("noumb")) put(&r_exp, 6, 2, 2);

        if (opt("novga13")) put(&r_vid, 0, 2, 1);
        else if (opt("vga13")) put(&r_vid, 0, 2, 2);

        if (joystick("joy1=", &r_inp, 0) < 0) return 1;
        if (joystick("joy2=", &r_inp, 2) < 0) return 1;

        if (opt("noswap")) put(&r_inp, 4, 2, 1);
        else if (opt("swap")) put(&r_inp, 4, 2, 2);

        if (opt("nojoysync")) put(&r_inp, 6, 2, 1);
        else if (opt("joysync")) put(&r_inp, 6, 2, 2);

        if (opt("mt32")) put(&r_midi, 0, 2, 1);
        else if (opt("gm")) put(&r_midi, 0, 2, 2);

        /* Say so rather than silently doing nothing with it. */
        for (i = 1; i < argc && i < 64; i++)
        {
            if (!matched[i])
            {
                printf("XTEGACTL: unknown option \"%s\"\n", argv[i]);
                return 1;
            }
        }
    }

    outp(P_CPU,  r_cpu);
    outp(P_EXP,  r_exp);
    outp(P_VID,  r_vid);
    outp(P_INP,  r_inp);
    outp(P_MIDI, r_midi);

    return 0;
}
