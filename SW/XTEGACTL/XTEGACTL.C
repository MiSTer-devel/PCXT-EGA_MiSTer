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
 * program never survives into the next one.  VGA 13h+ is the exception: it is
 * owned by VGATSR, so ordinary XTEGACTL invocations preserve its state.
 * "reset" also disables that extension.
 *
 * Build with Open Watcom:  wmake (wmake -a on Linux/WSL)
 */

#include <stdarg.h>
#include <dos.h>
#include <conio.h>
#include <string.h>

#define VERSION         "1.3"

/* Port block.  See rtl/KFPC-XT/HDL/xtegactl.sv for why it lives at 8980h and
   not next to the retired 8888h port. */
#define P_SIG           0x8980
#define P_CPU           0x8981
#define P_EXP           0x8982
#define P_VID           0x8983
#define P_INP           0x8984
#define P_MIDI          0x8985
#define P_EXP2          0x8986
#define P_CRT           0x8987
#define P_SYNC          0x8988
#define P_EFF_CPU       0x8989
#define P_EFF_INPUT     0x898A
#define P_EFF_MISC      0x898B
#define P_EFF_CRT       0x898C
#define P_EFF_SYNC      0x898D
#define P_OSD_MATCH_LO  0x898E
#define P_OSD_MATCH_HI  0x898F

#define SIGNATURE       0x45    /* 'E' */

/* Every field except VGA 13h+ reads 0 as "leave it to the OSD" and 1..N as
   the N choices, in the same order the OSD lists them. The Sound Blaster IRQ
   field is P_EXP2[5:4]: 1=IRQ5 and 2=IRQ7. VGA 13h+ starts off and is enabled
   by VGATSR through the same port. */
static unsigned char r_cpu, r_exp, r_vid, r_inp, r_midi, r_exp2, r_crt, r_sync;
static unsigned char e_cpu, e_input, e_misc, e_crt, e_sync;
static unsigned char osd_match_lo, osd_match_hi;

static int _argc;
static char **_argv;
static int matched[64];

/* Do not pull in stdio just to print diagnostics. Its Open Watcom startup
   code allocates one stream structure for each FILE before main(), which is
   unnecessary for this tiny utility and can fail on a heavily configured DOS
   environment. Write directly to the console through DOS instead. */
static void xputc(char c)
{
    union REGS regs;

    if (c == '\n') xputc('\r');
    regs.x.ax = 0;
    regs.x.dx = (unsigned char)c;
    regs.h.ah = 2;
    intdos(&regs, &regs);
}

static void xputs(char *text)
{
    while (*text != '\0') xputc(*text++);
}

static void xputu(unsigned int value)
{
    char digits[6];
    int count = 0;

    do
    {
        digits[count++] = (char)('0' + value % 10);
        value /= 10;
    } while (value != 0);

    while (count != 0) xputc(digits[--count]);
}

static void xputd(int value)
{
    if (value < 0)
    {
        xputc('-');
        value = -value;
    }
    xputu((unsigned int)value);
}

static void xprintf(char *format, ...)
{
    va_list args;

    va_start(args, format);
    while (*format != '\0')
    {
        if (*format != '%')
        {
            xputc(*format++);
            continue;
        }

        format++;
        switch (*format++)
        {
        case 's': xputs(va_arg(args, char *)); break;
        case 'u': xputu((unsigned int)va_arg(args, int)); break;
        case 'd': xputd(va_arg(args, int)); break;
        case 'c': xputc((char)va_arg(args, int)); break;
        case '%': xputc('%'); break;
        default:
            xputc('%');
            xputc(format[-1]);
            break;
        }
    }
    va_end(args);
}

#define printf xprintf

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
    printf("           cms  nocms      sb  nosb\n");
    printf("           sbirq=auto|5|7  Sound Blaster IRQ\n");
    printf("Memory     ems  noems       umb  noumb\n");
    printf("Input      joy1=analog|digital|off   joy2=analog|digital|off\n");
    printf("           swap  noswap      joysync  nojoysync\n");
    printf("MIDI       mt32  gm         mpu  nompu\n");
    printf("Tandy      tandy  notandy\n\n");
    printf("CRT        hpos=0..15  vpos=0..7  crt=auto\n");
    printf("Sync       hsync=auto|0..7  vsync=auto|0..7\n\n");
    printf("           reset       hand everything back to the OSD and disable VGA 13h+\n");
    printf("           status      show effective values; mark values matching OSD\n\n");
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

/* Reads PREFIX=N, accepting values from 0 through MAX. */
static int number(char *prefix, int max, unsigned char *value, int *present)
{
    char *v = choice(prefix);
    int n = 0;

    *present = 0;
    if (v == NULL) return 0;
    *present = 1;
    if (*v == '\0') goto bad;
    while (*v >= '0' && *v <= '9')
    {
        n = n * 10 + (*v++ - '0');
        if (n > max) goto bad;
    }
    if (*v != '\0') goto bad;
    *value = (unsigned char)n;
    return 0;

bad:
    printf("XTEGACTL: %s must be a value from 0 to %d\n", prefix, max);
    return -1;
}

/* Sync values use the same numeric range, with Auto as a readable alias for 0. */
static int sync_width(char *prefix, unsigned char *reg, int shift)
{
    char *v = choice(prefix);
    int n = 0;

    if (v == NULL) return 0;
    if (strcmpi(v, "auto") == 0) return 0;
    if (*v == '\0') goto bad;
    while (*v >= '0' && *v <= '9')
    {
        n = n * 10 + (*v++ - '0');
        if (n > 7) goto bad;
    }
    if (*v != '\0') goto bad;
    put(reg, shift, 3, (unsigned char)n);
    return 0;

bad:
    printf("XTEGACTL: %s must be auto or a value from 0 to 7\n", prefix);
    return -1;
}

/* The menu offers the two standard Sound Blaster IRQ jumper positions. */
static int soundblaster_irq(unsigned char *reg)
{
    char *v = choice("sbirq=");

    if (v == NULL) return 0;
    if (strcmpi(v, "5") == 0) put(reg, 4, 2, 1);
    else if (strcmpi(v, "7") == 0) put(reg, 4, 2, 2);
    else if (strcmpi(v, "auto") == 0) put(reg, 4, 2, 0);
    else
    {
        printf("XTEGACTL: sbirq must be auto, 5 or 7\n");
        return -1;
    }
    return 0;
}

/* The core exposes the two 220h occupants as independent overrides, while
   the OSD presents their mutually exclusive effective result as one field. */
static char *audio220_state(void)
{
    unsigned char cms = (unsigned char)((r_exp >> 2) & 3);
    unsigned char sb  = (unsigned char)((r_exp2 >> 2) & 3);

    /* Sound Blaster wins when both overrides request an enabled device. */
    if (sb == 1) return "Sound Blaster";
    if (cms == 1) return "CM/S";
    if (cms == 2 && sb == 2) return "Disabled";
    return "OSD";
}

static void show_legacy(void)
{
    static char *speed[5] = { "OSD", "4.77MHz", "7.16MHz", "9.54MHz", "Max" };
    static char *onoff[4] = { "OSD", "off", "on", "-" };
    /* VGA 13h+ has no OSD fallback: only field value 2 enables it. */
    static char *vga13[4] = { "off", "off", "on", "off" };
    static char *opl[4]   = { "OSD", "Adlib 388h", "SB FM 388h/228h", "disabled" };
    static char *enab[4]  = { "OSD", "enabled", "disabled", "-" };
    static char *joy[4]   = { "OSD", "analog", "digital", "disabled" };
    static char *midi[4]  = { "OSD", "MT-32", "General MIDI", "-" };
    static char *tandy[4] = { "OSD", "disabled", "enabled", "-" };
    static char *sb_irq[4] = { "OSD", "IRQ5", "IRQ7", "-" };
    unsigned char s;

    r_cpu  = (unsigned char)inp(P_CPU);
    r_exp  = (unsigned char)inp(P_EXP);
    r_vid  = (unsigned char)inp(P_VID);
    r_inp  = (unsigned char)inp(P_INP);
    r_midi = (unsigned char)inp(P_MIDI);
    r_exp2 = (unsigned char)inp(P_EXP2);
    r_crt  = (unsigned char)inp(P_CRT);
    r_sync = (unsigned char)inp(P_SYNC);

    s = (unsigned char)(r_cpu & 0x07);
    if (s > 4) s = 0;

    printf("XTEGACTL %s - current overrides\n\n", VERSION);
    printf("  CPU speed      %s\n", speed[s]);
    printf("  Fake 286 FLAGS %s\n", onoff[(r_cpu >> 3) & 3]);
    printf("  OPL2           %s\n", opl[r_exp & 3]);
    printf("  Audio 220h     %s\n", audio220_state());
    printf("  EMS            %s\n", enab[(r_exp >> 4) & 3]);
    printf("  UMB            %s\n", enab[(r_exp >> 6) & 3]);
    printf("  VGA 13h+       %s\n", vga13[r_vid & 3]);
    printf("  Joystick 1     %s\n", joy[r_inp & 3]);
    printf("  Joystick 2     %s\n", joy[(r_inp >> 2) & 3]);
    printf("  Swap joysticks %s\n", onoff[(r_inp >> 4) & 3]);
    printf("  Joy CPU sync   %s\n", onoff[(r_inp >> 6) & 3]);
    printf("  MT32-pi mode   %s\n", midi[r_midi & 3]);
    printf("  MPU-401        %s\n", enab[(r_midi >> 2) & 3]);
    printf("  Tandy sound    %s\n", tandy[r_exp2 & 3]);
    printf("  Sound Blaster IRQ %s\n", sb_irq[(r_exp2 >> 4) & 3]);
    if (r_crt & 0x80)
        printf("  CRT position   H=%u V=%u\n", r_crt & 15, (r_crt >> 4) & 7);
    else
        printf("  CRT position   OSD\n");
    printf("  HSync width    %s", ((r_sync >> 3) & 7) ? "fixed" : "Auto");
    if ((r_sync >> 3) & 7) printf(" (%u)\n", (r_sync >> 3) & 7);
    else printf("\n");
    printf("  VSync width    %s", (r_sync & 7) ? "fixed" : "Auto");
    if (r_sync & 7) printf(" (%u)\n", r_sync & 7);
    else printf("\n");
    printf("\n\"OSD\" means the menu setting is in force. VGA 13h+ is controlled by VGATSR.\n");
}

static int status_matches(int field)
{
    if (field < 8) return (osd_match_lo & (1 << field)) != 0;
    if (field < 16) return (osd_match_hi & (1 << (field - 8))) != 0;
    if (field == 16) return (e_sync & 0x40) != 0;
    return (e_sync & 0x80) != 0;
}

static char *status_suffix(int field)
{
    return status_matches(field) ? " (OSD)" : "";
}

static void show(void)
{
    static char *speed[4] = { "4.77MHz", "7.16MHz", "9.54MHz", "Max" };
    static char *onoff[2] = { "off", "on" };
    static char *opl[3] = { "Adlib 388h", "SB FM 388h/228h", "disabled" };
    static char *audio[3] = { "CM/S", "Sound Blaster", "disabled" };
    static char *enabled[2] = { "disabled", "enabled" };
    static char *joy[3] = { "analog", "digital", "disabled" };
    static char *midi[2] = { "MT-32", "General MIDI" };
    static char *irq[2] = { "IRQ5", "IRQ7" };
    unsigned char status_marker;
    unsigned char value;

    /* Raw values remain useful for the compatibility path and are harmless to
       read before checking whether this core implements the status extension. */
    r_cpu  = (unsigned char)inp(P_CPU);
    r_exp  = (unsigned char)inp(P_EXP);
    r_vid  = (unsigned char)inp(P_VID);
    r_inp  = (unsigned char)inp(P_INP);
    r_midi = (unsigned char)inp(P_MIDI);
    r_exp2 = (unsigned char)inp(P_EXP2);
    r_crt  = (unsigned char)inp(P_CRT);
    r_sync = (unsigned char)inp(P_SYNC);

    e_cpu        = (unsigned char)inp(P_EFF_CPU);
    e_input      = (unsigned char)inp(P_EFF_INPUT);
    e_misc       = (unsigned char)inp(P_EFF_MISC);
    e_crt        = (unsigned char)inp(P_EFF_CRT);
    e_sync       = (unsigned char)inp(P_EFF_SYNC);
    osd_match_lo = (unsigned char)inp(P_OSD_MATCH_LO);
    osd_match_hi = (unsigned char)inp(P_OSD_MATCH_HI);
    status_marker = (unsigned char)(e_misc & 0xC0);

    /* Cores before the effective-status extension still get the old useful
       override view instead of a screen full of misleading zeroes. */
    if (status_marker != 0x80)
    {
        show_legacy();
        return;
    }

    printf("XTEGACTL %s - current configuration\n\n", VERSION);

    printf("  CPU speed      %s%s\n", speed[e_cpu & 3], status_suffix(0));
    printf("  Fake 286 FLAGS %s%s\n", onoff[(e_cpu >> 3) & 1], status_suffix(1));
    printf("  OPL2           %s%s\n", opl[(e_cpu >> 4) & 3], status_suffix(2));
    printf("  Audio 220h     %s%s\n", audio[(e_cpu >> 6) & 3], status_suffix(3));
    printf("  EMS            %s%s\n", enabled[e_input & 1], status_suffix(4));
    printf("  UMB            %s%s\n", enabled[(e_input >> 1) & 1], status_suffix(5));
    /* VGA 13h+ has no OSD fallback: VGATSR owns its enable state. */
    printf("  VGA 13h+       %s\n", (e_input & 4) ? "on" : "off");
    printf("  Joystick 1     %s%s\n", joy[(e_input >> 3) & 3], status_suffix(6));
    printf("  Joystick 2     %s%s\n", joy[(e_input >> 5) & 3], status_suffix(7));
    printf("  Swap joysticks %s%s\n", onoff[(e_input >> 7) & 1], status_suffix(8));
    printf("  Joy CPU sync   %s%s\n", onoff[e_misc & 1], status_suffix(9));
    printf("  MT32-pi mode   %s%s\n", midi[(e_misc >> 1) & 1], status_suffix(10));
    printf("  MPU-401        %s%s\n", enabled[(e_misc >> 2) & 1], status_suffix(11));
    printf("  Tandy sound    %s%s\n", enabled[(e_misc >> 3) & 1], status_suffix(12));
    printf("  Sound Blaster IRQ %s%s\n", irq[(e_misc >> 5) & 1], status_suffix(13));
    printf("  CRT position   H=%u V=%u", e_crt & 15, (e_crt >> 4) & 7);
    printf("%s\n", status_suffix(14));
    value = (unsigned char)((e_sync >> 3) & 7);
    printf("  HSync width    %s", value ? "fixed" : "Auto");
    if (value) printf(" (%u)", value);
    printf("%s\n", status_suffix(17));
    value = (unsigned char)(e_sync & 7);
    printf("  VSync width    %s", value ? "fixed" : "Auto");
    if (value) printf(" (%u)", value);
    printf("%s\n", status_suffix(16));
    printf("\n\"(OSD)\" means the effective value matches the current menu setting.\n");
    printf("VGA 13h+ is controlled by VGATSR and therefore has no OSD marker.\n");
}

int main(int argc, char **argv)
{
    char *argv0, *bs;
    int i, hpos_present, vpos_present, preserve_vga13;
    unsigned char hpos = 0, vpos = 0;

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

    r_cpu = r_exp = r_inp = r_midi = r_exp2 = r_crt = r_sync = 0;
    /* VGATSR owns this field. Keep it untouched by ordinary game profiles. */
    r_vid = (unsigned char)inp(P_VID);
    preserve_vga13 = 1;

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

        if (opt("sb")) put(&r_exp2, 2, 2, 1);
        else if (opt("nosb")) put(&r_exp2, 2, 2, 2);

        if (soundblaster_irq(&r_exp2) < 0) return 1;

        if (opt("ems")) put(&r_exp, 4, 2, 1);
        else if (opt("noems")) put(&r_exp, 4, 2, 2);

        if (opt("umb")) put(&r_exp, 6, 2, 1);
        else if (opt("noumb")) put(&r_exp, 6, 2, 2);

        if (joystick("joy1=", &r_inp, 0) < 0) return 1;
        if (joystick("joy2=", &r_inp, 2) < 0) return 1;

        if (opt("noswap")) put(&r_inp, 4, 2, 1);
        else if (opt("swap")) put(&r_inp, 4, 2, 2);

        if (opt("nojoysync")) put(&r_inp, 6, 2, 1);
        else if (opt("joysync")) put(&r_inp, 6, 2, 2);

        if (opt("mt32")) put(&r_midi, 0, 2, 1);
        else if (opt("gm")) put(&r_midi, 0, 2, 2);

        if (opt("mpu")) put(&r_midi, 2, 2, 1);
        else if (opt("nompu")) put(&r_midi, 2, 2, 2);

        if (opt("tandy")) put(&r_exp2, 0, 2, 2);
        else if (opt("notandy")) put(&r_exp2, 0, 2, 1);

        if (opt("crt=auto"))
        {
            /* Explicit for clarity; the zeroed register already defers to OSD. */
        }
        if (number("hpos=", 15, &hpos, &hpos_present) < 0) return 1;
        if (number("vpos=", 7, &vpos, &vpos_present) < 0) return 1;
        if (hpos_present || vpos_present)
        {
            put(&r_crt, 0, 4, hpos);
            put(&r_crt, 4, 3, vpos);
            r_crt |= 0x80;
        }

        if (sync_width("hsync=", &r_sync, 3) < 0) return 1;
        if (sync_width("vsync=", &r_sync, 0) < 0) return 1;

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
    else
    {
        r_vid = 0;
        preserve_vga13 = 0;
    }

    outp(P_CPU,  r_cpu);
    outp(P_EXP,  r_exp);
    if (!preserve_vga13) outp(P_VID, r_vid);
    outp(P_INP,  r_inp);
    outp(P_MIDI, r_midi);
    outp(P_EXP2, r_exp2);
    outp(P_CRT,  r_crt);
    outp(P_SYNC, r_sync);

    return 0;
}
