// theme/quotes.mjs — separated quote & chaotic action pools, time/byte formatters, cover URL helper & font weights

// Actual attributed quotes by real people, authors, shows, and pioneers.
export const QUOTES = Object.freeze({
    "network_on": [
        "\"no matter where you go, everyone's connected.\" — lain",
        "\"the network is the computer.\" — john gage",
        "\"there is no cloud, it's just someone else's computer.\"",
        "\"information is not knowledge.\" — albert einstein",
        "\"the internet is not a luxury, it's a necessity.\" — barack obama",
        "\"we are all now connected by the internet, like neurons in a giant brain.\" — stephen hawking"
    ],
    "network_off": [
        "\"solitude is fine, but you need someone to tell that solitude is fine.\" — honoré de balzac",
        "\"the monotony and solitude of a quiet life stimulates the creative mind.\" — albert einstein",
        "\"no man is an island, entire of itself.\" — john donne",
        "\"hell is other people.\" — jean-paul sartre",
        "\"disconnect to reconnect.\""
    ],
    "battery_charging": [
        "\"energy is eternal delight.\" — william blake",
        "\"i am become death, the destroyer of worlds.\" — j. robert oppenheimer",
        "\"everything is energy and that's all there is to it.\" — albert einstein",
        "\"patience is bitter, but its fruit is sweet.\" — jean-jacques rousseau"
    ],
    "battery_low": [
        "\"don't panic.\" — douglas adams",
        "\"if you are going through hell, keep going.\" — winston churchill",
        "\"i love deadlines. i like the whooshing sound they make as they fly by.\" — douglas adams",
        "\"time is an illusion. lunchtime doubly so.\" — douglas adams",
        "\"everything ends, and it's always sad. but everything begins again too.\" — steven moffat"
    ],
    "battery_full": [
        "\"fortune favors the prepared mind.\" — louis pasteur",
        "\"ready when you are.\" — cecil b. demille",
        "\"to infinity and beyond.\" — buzz lightyear",
        "\"the best way out is always through.\" — robert frost"
    ],
    "media_playing": [
        "\"music is the shorthand of emotion.\" — leo tolstoy",
        "\"without music, life would be a mistake.\" — friedrich nietzsche",
        "\"where words fail, music speaks.\" — hans christian andersen",
        "\"music expresses that which cannot be put into words.\" — victor hugo",
        "\"one good thing about music, when it hits you, you feel no pain.\" — bob marley"
    ],
    "media_quiet": [
        "\"silence is a source of great strength.\" — lao tzu",
        "\"music is the space between the notes.\" — claude debussy",
        "\"the quieter you become, the more you are able to hear.\" — rumi",
        "\"silence is sometimes the best answer.\" — dalai lama",
        "\"in silence there is eloquence.\" — socrates"
    ],
    "notes_empty": [
        "\"simplicity is prerequisite for reliability.\" — edsger dijkstra",
        "\"perfection is achieved when there is nothing left to take away.\" — saint-exupéry",
        "\"a blank page is god's way of showing you how hard it is to be god.\" — lin-manuel miranda",
        "\"brevity is the soul of wit.\" — william shakespeare",
        "\"the secret of getting ahead is getting started.\" — mark twain"
    ],
    "notifs_empty": [
        "\"no news is good news.\" — james howell",
        "\"peace comes from within. do not seek it without.\" — buddha",
        "\"silence isn't empty, it's full of answers.\"",
        "\"the art of being wise is knowing what to overlook.\" — william james"
    ],
    "dnd_on": [
        "\"leave me alone, i know what i'm doing.\" — kimi räikkönen",
        "\"i think, therefore i am not answering slack.\" — rené descartes (probably)",
        "\"beware the fury of a patient man.\" — john dryden",
        "\"do not disturb my circles!\" — archimedes",
        "\"hell is other people's notifications.\" — sartre (adapted)"
    ],
    "volume_muted": [
        "\"better to remain silent and be thought a fool than speak.\" — maurice switzer",
        "\"speech is silver, silence is golden.\" — thomas carlyle",
        "\"he who knows does not speak.\" — lao tzu",
        "\"silence is the fence around wisdom.\" — talmud"
    ],
    "volume_high": [
        "\"these go to eleven.\" — nigel tufnel (spinal tap)",
        "\"too much of a good thing can be wonderful.\" — mae west",
        "\"speak softly and carry a big subwoofer.\" — theodore roosevelt (adapted)",
        "\"louder than god's revolver and twice as shiny.\" — pete wentz"
    ],
    "brightness_high": [
        "\"let there be light.\" — genesis 1:3",
        "\"stare not into the sun, lest the sun stare back.\" — nietzsche (adapted)",
        "\"give light and people will find the way.\" — ella baker",
        "\"it is a strange desire to seek light at 3 am.\""
    ],
    "brightness_low": [
        "\"there is a crack in everything, that's how the light gets in.\" — leonard cohen",
        "\"night is purer than day; it is better for thinking.\" — elie wiesel",
        "\"i'm a creature of the night.\" — dracula",
        "\"even the darkest night will end and the sun will rise.\" — victor hugo"
    ],
    "idle_inhibited": [
        "\"i'll sleep when i'm dead.\" — warren zevon",
        "\"do not go gentle into that good night.\" — dylan thomas",
        "\"perseverance is not a long race; it is many short races.\" — walter elliot",
        "\"sleep is for the weak.\" — every programmer ever"
    ],
    "idle_normal": [
        "\"rest when you're weary. refresh and renew yourself.\" — ralph marston",
        "\"sometimes the most productive thing you can do is relax.\" — mark black",
        "\"take rest; a field that has rested gives a bountiful crop.\" — ovid",
        "\"almost everything will work again if you unplug it for a few minutes.\" — anne lamott"
    ],
    "system": [
        "\"talk is cheap. show me the code.\" — linus torvalds",
        "\"an idiot admires complexity, a genius admires simplicity.\" — terry davis",
        "\"do one thing and do it well.\" — douglas mcilroy",
        "\"beware of bugs in the above code; i have only proved it correct, not tried it.\" — donald knuth",
        "\"premature optimization is the root of all evil.\" — donald knuth",
        "\"simple things should be simple, complex things should be possible.\" — alan kay",
        "\"when in doubt, use brute force.\" — ken thompson",
        "\"programs must be written for people to read.\" — harold abelson",
        "\"what i cannot create, i do not understand.\" — richard feynman",
        "\"debugging is twice as hard as writing the code in the first place.\" — brian kernighan",
        "\"there are only two kinds of languages: ones people complain about and ones nobody uses.\" — bjarne stroustrup",
        "\"it's easier to ask forgiveness than it is to get permission.\" — grace hopper"
    ],
    "screenshot": [
        "\"a picture is worth a thousand log lines.\" — fred r. barnard (adapted)",
        "\"you miss 100% of the screenshots you don't take.\" — wayne gretzky (probably)",
        "\"look at this photograph.\" — chad kroeger",
        "\"nothing is permanent except receipts.\" — heraclitus (adapted)"
    ]
});

// Chaotic / genuinely unhinged status actions & dev gremlin energy.
export const ACTIONS = Object.freeze({
    "network_on": [
        "curling a mystery script straight into sudo sh",
        "47 chromium tabs open for one nixos flake typo",
        "git push --force on main while everyone sleeps",
        "switching wifi mid-ssh just to feel alive",
        "downloading 3gb of node_modules so the fans scream",
        "blaming dns again (spoiler: it was dns)",
        "exposing localhost:3000 with zero authentication"
    ],
    "network_off": [
        "127.0.0.1 is the only friend that never flakes",
        "unplugged from society, hugging loopback interface",
        "networkmanager died on the cross for my nmcli sins",
        "staring at cached man pages like a 1998 cave goblin",
        "zero packets in or out, legally off the grid",
        "yelling into an unplugged ethernet port"
    ],
    "battery_charging": [
        "waterboarding a spicy pillow with 65w usb-c pd",
        "plugged in: cpu governor immediately goes feral",
        "cramming raw wall voltage straight into suffering lithium",
        "turning my lap into a hotplate while compiling rust",
        "chugging electrons like a 4am white monster"
    ],
    "battery_low": [
        "running on kernel panic adrenaline and 2% reserve",
        "where the hell is the usb-c brick",
        "2% left with 14 unsaved neovim buffers open",
        "one electron modal away from sudden flatline",
        "upower daemon quietly drafting my last will",
        "dimming the panel and begging the charger gods"
    ],
    "battery_full": [
        "100% charged (81% real health, don't check smartctl)",
        "unplugging immediately before the desk spontaneously ignites",
        "bms swears it's at 100%. bms is a chronic liar",
        "topped up and ready to dissociate on the couch"
    ],
    "media_playing": [
        "decoding lossless flac only to ruin it over $19 bluetooth",
        "spotify devouring 1.4gb of ram for a 2-minute song",
        "pipewire miraculously not crackling, don't breathe near it",
        "mpris snitching my questionable taste over dbus",
        "cava bars seizing violently in a corner"
    ],
    "media_quiet": [
        "just coil whine and case fans fighting for dominance",
        "wireplumber put the dac on unpaid leave again",
        "eerie 3am silence waiting for a discord ping flashbang",
        "staring at nothing while the radiator clanks"
    ],
    "notes_empty": [
        "vim buffer empty. frontal lobe empty",
        "zero tasks left (either productive or nuked the file)",
        "scratchpad completely blank like my short-term memory",
        "no chores written down because denial is free"
    ],
    "notifs_empty": [
        "zero @everyone pings ruining my peace right now",
        "dbus is suspiciously silent, what daemon crashed",
        "inbox zero because nobody wants to deal with me",
        "zero alerts, living in temporary delusion"
    ],
    "dnd_on": [
        "piping everyone's problems straight into /dev/null",
        "ping me on dnd and i'll rm -rf your router firmware",
        "firewalling port 80 of my remaining sanity",
        "do not disturb: breaking my dotfiles in peace"
    ],
    "volume_muted": [
        "muted before an unhinged autoplay ad blows the windows out",
        "holding wireplumber at gunpoint for total silence",
        "yeeting all pcm samples directly into the void",
        "muted on call—still paranoid the mic is hot"
    ],
    "volume_high": [
        "permanent tinnitus speedrun any% wr pace",
        "overdriving pipewire past 100% out of pure hatred",
        "speaker cones dialing the geneva conventions",
        "one chime away from leaving my physical body"
    ],
    "brightness_high": [
        "detonating a solar flashbang straight into both eyes",
        "retinas lightly sizzling at 100% backlight",
        "opened a white webpage at 3:17 am by accident",
        "burning the status bar permanently into the panel"
    ],
    "brightness_low": [
        "vampire cave lighting calibrated to maximum squint",
        "saving 0.3 watts of backlight like a feral raccoon",
        "dark enough that screen glare shows only regret"
    ],
    "idle_inhibited": [
        "pumping synthetic espresso straight into wayland",
        "holding dpms hostage until the rebuild stops failing",
        "refusing to sleep solely to watch a progress bar stall",
        "lockscreen told to wait outside in the rain"
    ],
    "idle_normal": [
        "cpu downclocked, brain also downclocked",
        "c-states dropping deep while i stare at the wallpaper",
        "zero active threads, peak goblin inactivity"
    ],
    "system": [
        "spent 4 hours ricing quickshell to dodge one tiny chore",
        "opened kitty, typed ls, saw nothing new, closed kitty",
        "nix store ballooning to 95gb out of sheer malice",
        "git commit -m 'idk man please work' at 3:47 am",
        "oom killer quietly measuring my chromium tabs for a coffin",
        "discord streaming 100% pure black pixels on wayland again",
        "restarting the whole compositor over a 1px corner scoop",
        "killing hung apps with -9 because asking is for cowards",
        "hyprland lua config standing upright on glue and spite",
        "30 days uptime because rebooting means admitting defeat"
    ],
    "screenshot": [
        "grim + slurp: fastest snitch in the tri-state area",
        "yoinking raw pixels straight to wl-clipboard",
        "allocating 40mb of ram to crop a cursed 8kb meme",
        "collecting court receipts for the group chat",
        "dumping another screenshot into ~/pictures to rot forever"
    ]
});

// Compatibility alias pointing to the unhinged actions pool.
export const FLAVOR_QUOTES = ACTIONS;

export function normalizeFlavorMode(mode) {
    if (mode === "hyprland" || mode === "quotes" || mode === "actions" || mode === "off") return mode;
    if (mode === "unhinged" || mode === "smart") return "actions";
    return "actions";
}

export function getFlavorPool(mode, category) {
    const m = normalizeFlavorMode(mode);
    if (m === "off" || m === "hyprland") return [];
    const table = m === "quotes" ? QUOTES : ACTIONS;
    return table[category] ?? table.system ?? [];
}

export function rollFlavor(mode, category, currentText = "", fallback = "") {
    const pool = getFlavorPool(mode, category);
    if (!pool || pool.length === 0) return (fallback ?? "").toLowerCase();
    if (pool.length === 1) return (pool[0] ?? fallback ?? "").toLowerCase();

    const cur = (currentText ?? "").toLowerCase();
    let idx = Math.floor(Math.random() * pool.length);
    if ((pool[idx] ?? "").toLowerCase() === cur) {
        idx = (idx + 1 + Math.floor(Math.random() * (pool.length - 1))) % pool.length;
    }
    return (pool[idx] ?? fallback ?? "").toLowerCase();
}

export function getFlavor(modeOrEnabled, hours, minutes, category, fallback, hyprSplash = "") {
    let mode;
    if (typeof modeOrEnabled === "string") {
        mode = normalizeFlavorMode(modeOrEnabled);
    } else {
        mode = modeOrEnabled ? "actions" : "off";
    }

    if (mode === "off") return (fallback ?? "").toLowerCase();
    if (mode === "hyprland") return (hyprSplash || fallback || "read the wiki.").toLowerCase();

    const list = getFlavorPool(mode, category);
    if (!list || list.length === 0) return (fallback ?? "").toLowerCase();

    const totalMinutes = hours * 60 + minutes;
    return (list[totalMinutes % list.length] ?? fallback ?? "").toLowerCase();
}

export function formatBytes(bytes) {
    if (!bytes || bytes <= 0 || isNaN(bytes)) return "0 b";
    const units = ["b", "kib", "mib", "gib", "tib"];
    const i = Math.max(0, Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024))));
    const val = bytes / Math.pow(1024, i);
    return (val >= 100 || i === 0 ? Math.round(val) : val.toFixed(1)) + " " + units[i];
}

export function formatUptime(sec) {
    if (!sec || sec <= 0 || isNaN(sec)) return "0m";
    const d = Math.floor(sec / 86400);
    const h = Math.floor((sec % 86400) / 3600);
    const m = Math.floor((sec % 3600) / 60);
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}

export function formatTime(seconds, padMinutes = false) {
    if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0) {
        return padMinutes ? "00:00" : "0:00";
    }
    const sec = Math.floor(seconds);
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    const mStr = padMinutes && m < 10 ? "0" + m : String(m);
    const sStr = s < 10 ? "0" + s : String(s);
    return mStr + ":" + sStr;
}

export function fixCoverUrl(url) {
    if (!url) return "";
    const cleaned = String(url).trim();
    return cleaned.startsWith("/") ? "file://" + cleaned : cleaned;
}

export function getFontWeight(weight, FontObj) {
    if (!weight || typeof weight !== "string") return FontObj.Normal;
    const map = {
        thin:       FontObj.Thin,
        extralight: FontObj.ExtraLight,
        ultralight: FontObj.ExtraLight,
        light:      FontObj.Light,
        normal:     FontObj.Normal,
        regular:    FontObj.Normal,
        medium:     FontObj.Medium,
        demibold:   FontObj.DemiBold,
        semibold:   FontObj.DemiBold,
        bold:       FontObj.Bold,
        extrabold:  FontObj.ExtraBold,
        ultrabold:  FontObj.ExtraBold,
        black:      FontObj.Black,
        heavy:      FontObj.Black
    };
    return map[weight.toLowerCase().trim()] ?? FontObj.Normal;
}
