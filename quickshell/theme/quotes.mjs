// theme/quotes.mjs — separated quote & chaotic action pools, time/byte formatters, cover URL helper & font weights

// Actual attributed quotes by real people, authors, shows, and pioneers.
export const QUOTES = Object.freeze({
    "network_on": [
        "\"no matter where you go, everyone's connected.\" — lain",
        "\"the network is the computer.\" — john gage",
        "\"there is no cloud, it's just someone else's computer.\"",
        "\"information is not knowledge.\" — albert einstein",
        "\"the internet is not a luxury, it's a necessity.\" — barack obama",
        "\"we are all now connected by the internet, like neurons in a giant brain.\" — stephen hawking",
        "\"the internet is the first thing that humanity has built that humanity doesn't understand.\" — eric schmidt",
        "\"any sufficiently advanced technology is indistinguishable from magic.\" — arthur c. clarke"
    ],
    "network_off": [
        "\"solitude is fine, but you need someone to tell that solitude is fine.\" — honoré de balzac",
        "\"the monotony and solitude of a quiet life stimulates the creative mind.\" — albert einstein",
        "\"no man is an island, entire of itself.\" — john donne",
        "\"hell is other people.\" — jean-paul sartre",
        "\"disconnect to reconnect.\"",
        "\"all of humanity's problems stem from man's inability to sit quietly in a room alone.\" — blaise pascal",
        "\"i never found the companion that was so companionable as solitude.\" — henry david thoreau"
    ],
    "battery_charging": [
        "\"energy is eternal delight.\" — william blake",
        "\"i am become death, the destroyer of worlds.\" — j. robert oppenheimer",
        "\"everything is energy and that's all there is to it.\" — albert einstein",
        "\"patience is bitter, but its fruit is sweet.\" — jean-jacques rousseau",
        "\"energy rightly applied and directed will accomplish anything.\" — nellie bly",
        "\"if you want to find the secrets of the universe, think in terms of energy, frequency and vibration.\" — nikola tesla"
    ],
    "battery_low": [
        "\"don't panic.\" — douglas adams",
        "\"if you are going through hell, keep going.\" — winston churchill",
        "\"i love deadlines. i like the whooshing sound they make as they fly by.\" — douglas adams",
        "\"time is an illusion. lunchtime doubly so.\" — douglas adams",
        "\"everything ends, and it's always sad. but everything begins again too.\" — steven moffat",
        "\"how we spend our days is, of course, how we spend our lives.\" — annie dillard",
        "\"the two most powerful warriors are patience and time.\" — leo tolstoy"
    ],
    "battery_full": [
        "\"fortune favors the prepared mind.\" — louis pasteur",
        "\"ready when you are.\" — cecil b. demille",
        "\"to infinity and beyond.\" — buzz lightyear",
        "\"the best way out is always through.\" — robert frost",
        "\"before anything else, preparation is the key to success.\" — alexander graham bell",
        "\"he who has a why to live can bear almost any how.\" — friedrich nietzsche"
    ],
    "media_playing": [
        "\"music is the shorthand of emotion.\" — leo tolstoy",
        "\"without music, life would be a mistake.\" — friedrich nietzsche",
        "\"where words fail, music speaks.\" — hans christian andersen",
        "\"music expresses that which cannot be put into words.\" — victor hugo",
        "\"one good thing about music, when it hits you, you feel no pain.\" — bob marley",
        "\"after silence, that which comes nearest to expressing the inexpressible is music.\" — aldous huxley",
        "\"music washes away from the soul the dust of everyday life.\" — berthold auerbach"
    ],
    "media_quiet": [
        "\"silence is a source of great strength.\" — lao tzu",
        "\"music is the space between the notes.\" — claude debussy",
        "\"the quieter you become, the more you are able to hear.\" — rumi",
        "\"silence is sometimes the best answer.\" — dalai lama",
        "\"in silence there is eloquence.\" — socrates",
        "\"he who does not understand your silence will probably not understand your words.\" — elbert hubbard",
        "\"silence is the sleep that nourishes wisdom.\" — francis bacon"
    ],
    "notes_empty": [
        "\"simplicity is prerequisite for reliability.\" — edsger dijkstra",
        "\"perfection is achieved when there is nothing left to take away.\" — saint-exupéry",
        "\"a blank page is god's way of showing you how hard it is to be god.\" — lin-manuel miranda",
        "\"brevity is the soul of wit.\" — william shakespeare",
        "\"the secret of getting ahead is getting started.\" — mark twain",
        "\"to attain knowledge, add things every day. to attain wisdom, remove things every day.\" — lao tzu",
        "\"order and simplification are the first steps toward the mastery of a subject.\" — thomas mann"
    ],
    "notifs_empty": [
        "\"no news is good news.\" — james howell",
        "\"peace comes from within. do not seek it without.\" — buddha",
        "\"silence isn't empty, it's full of answers.\"",
        "\"the art of being wise is knowing what to overlook.\" — william james",
        "\"you have power over your mind—not outside events. realize this, and you will find strength.\" — marcus aurelius",
        "\"stillness is where creativity and solutions to problems are found.\" — eckhart tolle"
    ],
    "dnd_on": [
        "\"leave me alone, i know what i'm doing.\" — kimi räikkönen",
        "\"i think, therefore i am not answering slack.\" — rené descartes (probably)",
        "\"beware the fury of a patient man.\" — john dryden",
        "\"do not disturb my circles!\" — archimedes",
        "\"hell is other people's notifications.\" — sartre (adapted)",
        "\"hell is empty and all the devils are here.\" — william shakespeare",
        "\"the ability to simplify means to eliminate the unnecessary so that the necessary may speak.\" — hans hofmann"
    ],
    "volume_muted": [
        "\"better to remain silent and be thought a fool than speak.\" — maurice switzer",
        "\"speech is silver, silence is golden.\" — thomas carlyle",
        "\"he who knows does not speak.\" — lao tzu",
        "\"silence is the fence around wisdom.\" — talmud",
        "\"well-timed silence hath more eloquence than speech.\" — martin farquhar tupper",
        "\"wise men speak because they have something to say; fools because they have to say something.\" — plato"
    ],
    "volume_high": [
        "\"these go to eleven.\" — nigel tufnel (spinal tap)",
        "\"too much of a good thing can be wonderful.\" — mae west",
        "\"speak softly and carry a big subwoofer.\" — theodore roosevelt (adapted)",
        "\"louder than god's revolver and twice as shiny.\" — pete wentz",
        "\"music is the strongest form of magic.\" — marilyn manson",
        "\"one ought, every day at least, to hear a little song.\" — johann wolfgang von goethe"
    ],
    "brightness_high": [
        "\"let there be light.\" — genesis 1:3",
        "\"stare not into the sun, lest the sun stare back.\" — nietzsche (adapted)",
        "\"give light and people will find the way.\" — ella baker",
        "\"it is a strange desire to seek light at 3 am.\"",
        "\"there are two ways of spreading light: to be the candle or the mirror that reflects it.\" — edith wharton",
        "\"nothing can dim the light which shines from within.\" — maya angelou"
    ],
    "brightness_low": [
        "\"there is a crack in everything, that's how the light gets in.\" — leonard cohen",
        "\"night is purer than day; it is better for thinking.\" — elie wiesel",
        "\"i'm a creature of the night.\" — dracula",
        "\"even the darkest night will end and the sun will rise.\" — victor hugo",
        "\"darkness cannot drive out darkness; only light can do that.\" — martin luther king jr.",
        "\"the stars are not afraid to appear like fireflies.\" — rabindranath tagore"
    ],
    "idle_inhibited": [
        "\"i'll sleep when i'm dead.\" — warren zevon",
        "\"do not go gentle into that good night.\" — dylan thomas",
        "\"perseverance is not a long race; it is many short races.\" — walter elliot",
        "\"sleep is for the weak.\" — every programmer ever",
        "\"the woods are lovely, dark and deep, but i have promises to keep, and miles to go before i sleep.\" — robert frost",
        "\"never give in, never, never, never.\" — winston churchill"
    ],
    "idle_normal": [
        "\"rest when you're weary. refresh and renew yourself.\" — ralph marston",
        "\"sometimes the most productive thing you can do is relax.\" — mark black",
        "\"take rest; a field that has rested gives a bountiful crop.\" — ovid",
        "\"almost everything will work again if you unplug it for a few minutes.\" — anne lamott",
        "\"time you enjoy wasting is not wasted time.\" — marthe troly-curtin",
        "\"there is virtue in work and there is virtue in rest. use both and overlook neither.\" — alan cohen"
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
        "\"it's easier to ask forgiveness than it is to get permission.\" — grace hopper",
        "\"simplicity is about subtracting the obvious and adding the meaningful.\" — john maeda",
        "\"first, solve the problem. then, write the code.\" — john johnson",
        "\"controlling complexity is the essence of computer programming.\" — brian kernighan",
        "\"one of my most productive days was throwing away 1,000 lines of code.\" — ken thompson",
        "\"if debugging is the process of removing software bugs, then programming must be the process of putting them in.\" — edsger dijkstra"
    ],
    "screenshot": [
        "\"a picture is worth a thousand log lines.\" — fred r. barnard (adapted)",
        "\"you miss 100% of the screenshots you don't take.\" — wayne gretzky (probably)",
        "\"look at this photograph.\" — chad kroeger",
        "\"nothing is permanent except receipts.\" — heraclitus (adapted)",
        "\"which of my photographs is my favorite? the one i'm going to take tomorrow.\" — imogen cunningham",
        "\"in photography there is a reality so subtle that it becomes more real than reality.\" — alfred stieglitz"
    ]
});

// Present-tense status actions & terminal commentary.
export const ACTIONS = Object.freeze({
    "network_on": [
        "curling a mystery script straight into sudo sh",
        "47 chromium tabs open for one nixos flake typo",
        "git push --force on main while everyone sleeps",
        "switching wifi mid-ssh just to feel alive",
        "downloading 3gb of node_modules so the fans scream",
        "blaming dns again (spoiler: it was dns)",
        "exposing localhost:3000 with zero authentication",
        "running traceroute just to watch packets suffer across twelve hops",
        "restarting systemd-resolved again because caching lied"
    ],
    "network_off": [
        "127.0.0.1 is the only friend that never flakes",
        "unplugged from society, hugging loopback interface",
        "networkmanager died on the cross for my nmcli sins",
        "staring at cached man pages like a 1998 cave goblin",
        "zero packets in or out, legally off the grid",
        "yelling into an unplugged ethernet port",
        "pinging 1.1.1.1 twice just in case physics changed",
        "editing /etc/hosts out of pure resentment"
    ],
    "battery_charging": [
        "waterboarding a spicy pillow with 65w usb-c pd",
        "plugged in: cpu governor immediately goes feral",
        "cramming raw wall voltage straight into suffering lithium",
        "turning my lap into a hotplate while compiling rust",
        "chugging electrons like a 4am white monster",
        "watching wattage bounce between 45w and 65w like a heart monitor",
        "feeding usb-c pd into a laptop that begs for mercy"
    ],
    "battery_low": [
        "running on kernel panic adrenaline and 2% reserve",
        "where the hell is the usb-c brick",
        "2% left with 14 unsaved neovim buffers open",
        "one electron modal away from sudden flatline",
        "upower daemon quietly drafting my last will",
        "dimming the panel and begging the charger gods",
        "underclocking my will to live to stretch the last 4%",
        "closing browser tabs like jettisoning cargo from a falling plane"
    ],
    "battery_full": [
        "100% charged (81% real health, don't check smartctl)",
        "unplugging immediately before the desk spontaneously ignites",
        "bms swears it's at 100%. bms is a chronic liar",
        "topped up and ready to dissociate on the couch",
        "topped off and looking for something heavy to compile"
    ],
    "media_playing": [
        "decoding lossless flac only to ruin it over $19 bluetooth",
        "spotify devouring 1.4gb of ram for a 2-minute song",
        "pipewire miraculously not crackling, don't breathe near it",
        "mpris snitching my questionable taste over dbus",
        "cava bars seizing violently in a corner",
        "replaying the same 180-second track until dopamine stops responding",
        "trusting pipewire not to switch back to laptop speakers mid-chorus"
    ],
    "media_quiet": [
        "just coil whine and case fans fighting for dominance",
        "wireplumber put the dac on unpaid leave again",
        "eerie 3am silence waiting for a discord ping flashbang",
        "staring at nothing while the radiator clanks",
        "paused on a cliffhanger while forgetting the tab existed"
    ],
    "notes_empty": [
        "vim buffer empty. frontal lobe empty",
        "zero tasks left (either productive or nuked the file)",
        "scratchpad completely blank like my short-term memory",
        "no chores written down because denial is free",
        "zero sticky notes left, only suppressed guilt",
        "closed the todo list so technically i'm caught up"
    ],
    "notifs_empty": [
        "zero @everyone pings ruining my peace right now",
        "dbus is suspiciously silent, what daemon crashed",
        "inbox zero because nobody wants to deal with me",
        "zero alerts, living in temporary delusion",
        "either everyone muted me or dbus-broker died silently",
        "no unread alerts to ignore until midnight"
    ],
    "dnd_on": [
        "piping everyone's problems straight into /dev/null",
        "ping me on dnd and i'll rm -rf your router firmware",
        "firewalling port 80 of my remaining sanity",
        "do not disturb: breaking my dotfiles in peace",
        "silencing desktop toasts before one badge ruins the flow",
        "pretending nobody can reach me if the bell icon is crossed out"
    ],
    "volume_muted": [
        "muted before an unhinged autoplay ad blows the windows out",
        "holding wireplumber at gunpoint for total silence",
        "yeeting all pcm samples directly into the void",
        "muted on call—still paranoid the mic is hot",
        "zero db output, maximum internal monologue",
        "hardware muted because software mute has betrayed me before"
    ],
    "volume_high": [
        "permanent tinnitus speedrun any% wr pace",
        "overdriving pipewire past 100% out of pure hatred",
        "speaker cones dialing the geneva conventions",
        "one chime away from leaving my physical body",
        "pushing mixer slider into the danger zone for two measures",
        "testing how much distortion my headphones tolerate"
    ],
    "brightness_high": [
        "detonating a solar flashbang straight into both eyes",
        "retinas lightly sizzling at 100% backlight",
        "opened a white webpage at 3:17 am by accident",
        "burning the status bar permanently into the panel",
        "backlight maxed like an airport runway beacon"
    ],
    "brightness_low": [
        "vampire cave lighting calibrated to maximum squint",
        "saving 0.3 watts of backlight like a feral raccoon",
        "dark enough that screen glare shows only regret",
        "lowest backlight notch to preserve nocturnal eyesight"
    ],
    "idle_inhibited": [
        "pumping synthetic espresso straight into wayland",
        "holding dpms hostage until the rebuild stops failing",
        "refusing to sleep solely to watch a progress bar stall",
        "lockscreen told to wait outside in the rain",
        "blocking dpms sleep so a long command finishes unattended"
    ],
    "idle_normal": [
        "cpu downclocked, brain also downclocked",
        "c-states dropping deep while i stare at the wallpaper",
        "zero active threads, peak goblin inactivity",
        "no input events, keyboard collecting dust"
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
        "30 days uptime because rebooting means admitting defeat",
        "editing six config files instead of finishing one task",
        "reading journalctl output like it owes me money",
        "cleaning ~/.cache just to feel temporary control",
        "blaming wayland before checking if i saved the file"
    ],
    "screenshot": [
        "grim + slurp: fastest snitch in the tri-state area",
        "yoinking raw pixels straight to wl-clipboard",
        "allocating 40mb of ram to crop a cursed 8kb meme",
        "collecting court receipts for the group chat",
        "dumping another screenshot into ~/pictures to rot forever",
        "cropping a window border five times until the padding feels right",
        "capturing evidence before restarting the daemon"
    ]
});

// Compatibility alias pointing to the actions pool.
export const FLAVOR_QUOTES = ACTIONS;

// Upstream Hyprland NSplashes pool (no compositor restart needed to reroll).
export const HYPRLAND_SPLASHES = Object.freeze([
    "Woo, animations!",
    "It's like Hypr, but better.",
    "Release 1.0 when?",
    "It's not awesome, it's Hyprland!",
    "\"I commit too often, people can't catch up lmao\" - Vaxry",
    "This text is random.",
    "\"There are reasons to not use rust.\" - Boga",
    "Read the wiki.",
    "\"Hello everyone this is YOUR daily dose of 'read the wiki'\" - Vaxry",
    "h",
    "\"'why no work', bro I haven't hacked your pc to get live feeds yet\" - Vaxry",
    "Compile, wait for 20 minutes, notice a new commit, compile again.",
    "To rice, or not to rice, that is the question.",
    "Now available on Fedora!",
    "\"Hyprland is so good it starts with a capital letter\" - Hazel",
    "\"please make this message a splash\" - eriedaberrie",
    "\"the only wayland compositor powered by fried chicken\" - raf",
    "\"This will never get into Hyprland\" - Flafy",
    "\"Hyprland only gives you up on -git\" - fazzi",
    "Segmentation fault (core dumped)",
    "\"disabling hyprland logo is a war crime\" - vaxry",
    "some basic startup code",
    "\"I think I am addicted to hyprland\" - mathisbuilder",
    "Thanks Brodie!",
    "Thanks fufexan!",
    "Thanks raf!",
    "You can't use --splash to change this message :)",
    "Hyprland will overtake Gnome in popularity by [insert year]",
    "Designed in California - Assembled in China",
    "\"something <time here> and still no new splash\" - snowman",
    "My name is Land. Hypr Land. One red bull, shaken not stirred.",
    "\"Glory To The Emperor\" - raf",
    "Help I forgot to install kitty",
    "Go to settings to activate Hyprland",
    "Why is there code??? Make a damn .exe file and give it to me.",
    "Hyprland is not a window manager!",
    "Can we get a version without anime girls?",
    "Check out quickshell!",
    "A day without Hyprland is a day wasted",
    "By dt, do you mean damage tracking or distrotube?",
    "Made in Poland",
    "\"I use Arch, btw\" - John Cena",
    "\"Hyper\".replace(\"e\", \"\")",
    "\"my win11 install runs hyprland that is true\" - raf",
    "\"stop playing league loser\" - hyprBot",
    "\"If it ain't broke, don't fix it\" - Lucascito_03",
    "\"@vaxry how do i learn c++\" - flicko",
    "Join the discord server!",
    "Thanks ThatOneCalculator!",
    "The AUR packages always work, except for the times they don't.",
    "Funny animation compositor woo",
    "4 years!",
    "Beauty will save the world",
    "Get good",
    "Configration",
    "RIP hyprlang",
    "better call vaxry",
    "i hypr therefore i land",
    "five. hundred. config errors.",
    "bundled with anime girls for your convenience",
    "now with 200% more hypr and land",
    "daily dose of rice",
    "Removed Herobrine",
    "You should try quickshell!",
    "He was an X11 boy, she was a Wayland girl...",
    "How do I exit vim????",
    "Now with lua, it might as well be awesome.",
    "Have you ran your daily fastfetch yet?"
]);

export const HYPRLAND_SPLASHES_CHRISTMAS = Object.freeze([
    "Merry Christmas!",
    "Merry Xmas!",
    "Ho ho ho",
    "Santa was here",
    "Make sure to spend some jolly time with those near and dear to you!",
    "Have you checked for christmas presents yet?"
]);

function getHyprlandNewYearSplashes(now = new Date()) {
    const mon = now.getMonth();
    const yr = now.getFullYear();
    const newYear = mon < 8 ? yr : yr + 1;
    return [
        "Happy new Year!",
        "[New year] will be the year of the Linux desktop!",
        "[New year] will be the year of the Hyprland desktop!",
        `${newYear} will be the year of the Linux desktop!`,
        `${newYear} will be the year of the Hyprland desktop!`,
        `Let's make ${newYear} even better than ${newYear - 1}!`
    ];
}

function getHyprlandSeasonPool(now = new Date()) {
    const mon = now.getMonth();
    const day = now.getDate();
    if (mon === 11 && day >= 20 && day <= 27) {
        return HYPRLAND_SPLASHES.concat(HYPRLAND_SPLASHES_CHRISTMAS);
    }
    if ((mon === 11 && day >= 29) || (mon === 0 && day <= 5)) {
        return HYPRLAND_SPLASHES.concat(getHyprlandNewYearSplashes(now));
    }
    return HYPRLAND_SPLASHES;
}

// Delirium splashes: mirrors Hyprland's splash style & classics, localized to Ashley's dotfiles with deadpan realism and intentional typos.
export const DELIRIUM_SPLASHES = Object.freeze([
    // classic hyprland splashes kept in the family
    "Woo, animations!",
    "Release 1.0 when?",
    "This text is random.",
    "h",
    "To rice, or not to rice, that is the question.",
    "some basic startup code",
    "By dt, do you mean damage tracking or distrotube?",
    "Beauty will save the world",
    "Get good",
    "Configration",
    "RIP hyprlang",
    "i hypr therefore i land",
    "daily dose of rice",
    "Removed Herobrine",
    "You should try quickshell!",
    "He was an X11 boy, she was a Wayland girl...",
    "How do I exit vim????",
    "Have you ran your daily fastfetch yet?",

    // hyprland splashes remixed with delirium, ashley, seth & our stack
    "It's like my_hyprland_dots, but better.",
    "It's not caelestia, it's delirium!",
    "\"I commit too often, the lockfile can't catch up lmao\" - ashley",
    "\"There are reasons to not edit qml at 4am.\" - seth",
    "Read BACKSTORY.md.",
    "\"Hello everyone this is YOUR daily dose of 'check /run/user/1000/quickshell'\" - seth",
    "\"'why no work', bro I haven't hacked your thinkpad to get live feeds yet\" - seth",
    "Rebuild, wait for 20 minutes, notice a typo in lua, rebuild again.",
    "Now available on 7.6g of volatile tmpfs!",
    "\"delirium is so serious it enforces strict lowercase\" - ashley",
    "\"please make this message a splash\" - ashley",
    "\"the only dotfiles held upright by nixos rollbacks\" - ashley",
    "\"This will never pass ./install.zsh --doctor\" - seth",
    "\"delirium only gives you up after npm install\" - ashley",
    "Segmentation fault (core dumped to tty1)",
    "\"storing .json in ~/.local/state is a war crime\" - ashley",
    "\"I think I am addicted to quickshell\" - ashley",
    "Thanks ashley!",
    "Thanks fufexan!",
    "Thanks seth!",
    "You can't use --splash to fix this message :)",
    "delirium will overtake caelestia in popularity by [insert year]",
    "ashley will finish ricing gnome 51 by [insert year]",
    "Designed on a ThinkPad T16 - Assembled at 3am",
    "\"something <4:10 am> and still no clean rebuild\" - ashley",
    "My name is Shell. Quick Shell. One generation, rolled back.",
    "\"Glory To @persist\" - ashley",
    "Help I forgot ptyxis runs inside flatpak",
    "Go to settings to activate delirium",
    "Why is there qml??? Make a damn .conf file and give it to me.",
    "delirium is not a desktop environment!",
    "Can we get a version without 1,000 wallhaven files?",
    "Check out Brain_Shell!",
    "A day without nixos is a day spent reinstalling after blkdiscard",
    "Made in 7.6g ramdisk",
    "\"I used Arch, btw\" - Ashley (before atomic-lockfile)",
    "\"delirium\".replace(\"sanity\", \"\")",
    "\"my windows partition got wiped with blkdiscard that is true\" - ashley",
    "\"stop rewriting the readme loser\" - seth",
    "\"If it ain't broke, break it and roll back\" - ashley",
    "\"@seth how do i exit neovim with ijkl\" - ashley",
    "Don't open a pull request, jules is dead!",
    "Nobody left in github issues!",
    "The nixos rebuilds always pass, except for the times / runs out of tmpfs.",
    "Funny animation lockscreen pill woo",
    "5 hours of gentoo!",
    "better call seth",
    "five. hundred. qml errors.",
    "bundled with broken anchors for your convenience",
    "now with 200% more delirium and swap",
    "daily dose of delirium",
    "Removed jules",
    "You should try end-4! (if you have a sleep schedule)",
    "Now with lua tables, it might as well be broke.",

    // deadpan & realism splashes in hyprland format
    "60hz panel, 240hz expectations.",
    "1920x1200@60hz.",
    "Powered by a bowing ThinkPad T16 Gen 1.",
    "MX550 sitting idle on nouveau as a hand warmer.",
    "Everything outside @persist dies when the capacitors drain.",
    "Zero electron binaries detected.",
    "\"npm install atomic-lockfile\" - famous last words",
    "If anyone would check on you after three days of silence, close this tab.",
    "43.6 / 52.5 Wh remaining.",
    "Fan curve hijacked from lenovo ec firmware.",
    "Warning: local agents edited this while unsupervised.",
    "Tuned strictly around stiff knuckles and bad habits.",
    "Release 1.0 canceled, moving to delirium 0.0.",
    "Have you run your daily sysup yet?",
    "One pam error away from tty3.",
    "hyprctl --instance 0 won't save you this time.",
    "No .json files were harmed.",
    "Two terminals: kitty for hyprland, ptyxis for gnome.",
    "Built while dodging a real chore.",
    "Everything outside /persist is temporary.",
    "Check coredumpctl if the compositor vanishes.",
    "seth approved 0% of this.",

    // intentional spelling errors & typos
    "Its like my_hyprland_dots, but beter.",
    "Read the wikki.",
    "some basik startup code",
    "delirium is not a windwo manager!",
    "five. hundrd. config errors.",
    "Complie, wait 20 mins, notice new comit, complie agian.",
    "Desgined in neovim - Assembled at 3am",
    "Funny animaton compositor woo",
    "Have u ran ur daily fastfech yet?",
    "You shoud try quickshell!",
    "daily doze of delirium",
    "Now avaliable on volatile tmpfs!",
    "Segmentaton fault (core dumped)"
]);

export const DELIRIUM_SPLASHES_CHRISTMAS = Object.freeze([
    "Merry Christmas!",
    "Merry Xmas!",
    "Ho ho ho",
    "Santa left a broken flake.lock",
    "Make sure to spend some jolly time with those near the radiator!",
    "Have you checked if anything survived @persist yet?"
]);

function getDeliriumNewYearSplashes(now = new Date()) {
    const mon = now.getMonth();
    const yr = now.getFullYear();
    const newYear = mon < 8 ? yr : yr + 1;
    return [
        "Happy new Year!",
        "[New year] will be the year of a clean nix generation!",
        "[New year] will be the year of the delirium desktop!",
        `${newYear} will be the year of the NixOS desktop!`,
        `${newYear} will be the year of the delirium desktop!`,
        `Let's roll back ${newYear} less than ${newYear - 1}!`
    ];
}

function getDeliriumSeasonPool(now = new Date()) {
    const mon = now.getMonth();
    const day = now.getDate();
    if (mon === 11 && day >= 20 && day <= 27) {
        return DELIRIUM_SPLASHES.concat(DELIRIUM_SPLASHES_CHRISTMAS);
    }
    if ((mon === 11 && day >= 29) || (mon === 0 && day <= 5)) {
        return DELIRIUM_SPLASHES.concat(getDeliriumNewYearSplashes(now));
    }
    return DELIRIUM_SPLASHES;
}

export function normalizeFlavorMode(mode) {
    if (mode === "hyprland" || mode === "delirium" || mode === "quotes" || mode === "actions" || mode === "off") return mode;
    if (mode === "unhinged" || mode === "smart") return "actions";
    return "actions";
}

export function getFlavorPool(mode, category) {
    const m = normalizeFlavorMode(mode);
    if (m === "off") return [];
    if (m === "hyprland") return getHyprlandSeasonPool();
    if (m === "delirium") return getDeliriumSeasonPool();
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

    const list = getFlavorPool(mode, category);
    if (!list || list.length === 0) return ((hyprSplash || fallback) ?? "").toLowerCase();

    let offset = 0;
    if (mode === "hyprland" || mode === "delirium") {
        const c = String(category || "system");
        for (let i = 0; i < c.length; i++) {
            offset = (offset * 31 + c.charCodeAt(i)) | 0;
        }
        offset = Math.abs(offset);
    }

    const totalMinutes = hours * 60 + minutes + offset;
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
