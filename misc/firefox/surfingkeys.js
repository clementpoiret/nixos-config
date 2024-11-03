// a very tridactyl-esque config file.

// compatibility prefix
const {
  clipboard,
  front,
  hints,
  normal,
  runtime,
  visual,
  acevimmap,
  addsearchalias,
  cmap,
  getclickableelements,
  imap,
  imapkey,
  iunmap,
  map,
  mapkey,
  readtext,
  removesearchalias,
  tabopenlink,
  unmap,
  unmapallexcept,
  vmapkey,
  vunmap,
} = api;

// ---- settings ----
hints.setcharacters("asdfgyuiopqwertnmzxcvb");

settings.defaultsearchengine = "d";
settings.hintalign = "left";
settings.omnibarposition = "bottom";
settings.focusfirstcandidate = false;
settings.focusafterclosed = "last";
settings.scrollstepsize = 200;
settings.tabsthreshold = 0;
settings.modeafteryank = "normal";

// ---- map -----
// --- hints ---
// open multiple links
map("<alt-f>", "cf");

// yank link url
map("<alt-y>", "ya");
map("<alt-u>", "ya");

// open hint in new tab
map("f", "c");

// --- nav ---
// open clipboard url in current tab
mapkey("p", "open the clipboard's url in the current tab", () => {
  clipboard.read(function (response) {
    window.location.href = response.data;
  });
});

// open clipboard url in new tab
map("p", "cc");

// open a url in current tab
map("o", "go");

// choose a buffer/tab
map("b", "t");

// edit current url, and open in same tab
map("o", ";u");

// edit current url, and open in new tab
map("t", ";u");

// history back/forward
map("h", "s");
map("l", "d");

// scroll page down/up
mapkey("<ctrl-d>", "scroll down", () => {
  normal.scroll("pagedown");
});
mapkey("<ctrl-u>", "scroll up", () => {
  normal.scroll("pageup");
});
map("<ctrl-b>", "u"); // scroll full page up
//map('<ctrl-f>', 'p');  // scroll full page down -- looks like we can't overwrite browser-native binding

// next/prev page
map("k", "[[");
map("j", "]]");

// open chrome flags
mapkey("gf", "#12open chrome flags", () => {
  tabopenlink("chrome://flags/");
});

// --- tabs ---
// tab delete/undo
map("d", "x");
mapkey("d", "#3close current tab", () => {
  runtime("closetab");
});
mapkey("u", "#3restore closed tab", () => {
  runtime("openlast");
});

// move tab left/right w/ one press
map(">", ">>");
map("<", "<<");

// tab next/prev
map("<alt-j>", "r");
map("<alt-k>", "e");

// --- misc ---
// yank url w/ one press (disables other yx binds)
map("y", "yy");

// change focused frame
map("gf", "w");

// ---- unmap -----
// proxy stuff
unmap("spa");
unmap("spb");
unmap("spc");
unmap("spd");
unmap("sps");
unmap("cp");
unmap(";cp");
unmap(";ap");

// emoji
iunmap(":");

// misc
unmap(";t");
unmap("si");
unmap("ga");
unmap("gc");
unmap("gn");
unmap("gr");
unmap("ob");
unmap("og");
unmap("od");
unmap("oy");

// ---- search engines -----
removesearchalias("b", "s");
removesearchalias("d", "s");
removesearchalias("g", "s");
removesearchalias("h", "s");
removesearchalias("w", "s");
removesearchalias("y", "s");
removesearchalias("s", "s");

addsearchalias("k", "kagi", "https://kagi.com/search?q=", "s");
addsearchalias(
  "n",
  "nixp",
  "https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=",
  "s",
);
addsearchalias("gh", "github", "https://github.com/search?q=", "s");
addsearchalias("pdb", "proton", "https://www.protondb.com/search?q=", "s");

// theme
// todo: configure
hints.style(
  "border: solid 2px #282c34; color:#98be65; background: initial; background-color: #2e3440;",
);
hints.style(
  "border: solid 2px #282c34 !important; padding: 1px !important; color: #51afef !important; background: #2e3440 !important;",
  "text",
);
visual.style("marks", "background-color: #98be6599;");
visual.style("cursor", "background-color: #51afef;");

settings.theme = `
/* edit these variables for easy theme making */
:root {
  /* font */
  --font: 'source code pro', ubuntu, sans;
  --font-size: 12;
  --font-weight: bold;

  --fg: #c5c8c6;
  --bg: #282a2e;
  --bg-dark: #1d1f21;
  --border: #373b41;
  --main-fg: #81a2be;
  --accent-fg: #52c196;
  --info-fg: #ac7bba;
  --select: #585858;
}

/* ---------- generic ---------- */
.sk_theme {
background: var(--bg);
color: var(--fg);
  background-color: var(--bg);
  border-color: var(--border);
  font-family: var(--font);
  font-size: var(--font-size);
  font-weight: var(--font-weight);
}

input {
  font-family: var(--font);
  font-weight: var(--font-weight);
}

.sk_theme tbody {
  color: var(--fg);
}

.sk_theme input {
  color: var(--fg);
}

/* hints */
#sk_hints .begin {
  color: var(--accent-fg) !important;
}

#sk_tabs .sk_tab {
  background: var(--bg-dark);
  border: 1px solid var(--border);
}

#sk_tabs .sk_tab_title {
  color: var(--fg);
}

#sk_tabs .sk_tab_url {
  color: var(--main-fg);
}

#sk_tabs .sk_tab_hint {
  background: var(--bg);
  border: 1px solid var(--border);
  color: var(--accent-fg);
}

.sk_theme #sk_frame {
  background: var(--bg);
  opacity: 0.2;
  color: var(--accent-fg);
}

/* ---------- omnibar ---------- */
/* uncomment this and use settings.omnibarposition = 'bottom' for pentadactyl/tridactyl style bottom bar */
/* .sk_theme#sk_omnibar {
  width: 100%;
  left: 0;
} */

.sk_theme .title {
  color: var(--accent-fg);
}

.sk_theme .url {
  color: var(--main-fg);
}

.sk_theme .annotation {
  color: var(--accent-fg);
}

.sk_theme .omnibar_highlight {
  color: var(--accent-fg);
}

.sk_theme .omnibar_timestamp {
  color: var(--info-fg);
}

.sk_theme .omnibar_visitcount {
  color: var(--accent-fg);
}

.sk_theme #sk_omnibarsearchresult ul li:nth-child(odd) {
  background: var(--bg-dark);
}

.sk_theme #sk_omnibarsearchresult ul li.focused {
  background: var(--border);
}

.sk_theme #sk_omnibarsearcharea {
  border-top-color: var(--border);
  border-bottom-color: var(--border);
}

.sk_theme #sk_omnibarsearcharea input,
.sk_theme #sk_omnibarsearcharea span {
  font-size: var(--font-size);
}

.sk_theme .separator {
  color: var(--accent-fg);
}

/* ---------- popup notification banner ---------- */
#sk_banner {
  font-family: var(--font);
  font-size: var(--font-size);
  font-weight: var(--font-weight);
  background: var(--bg);
  border-color: var(--border);
  color: var(--fg);
  opacity: 0.9;
}

/* ---------- popup keys ---------- */
#sk_keystroke {
  background-color: var(--bg);
}

.sk_theme kbd .candidates {
  color: var(--info-fg);
}

.sk_theme span.annotation {
  color: var(--accent-fg);
}

/* ---------- popup translation bubble ---------- */
#sk_bubble {
  background-color: var(--bg) !important;
  color: var(--fg) !important;
  border-color: var(--border) !important;
}

#sk_bubble * {
  color: var(--fg) !important;
}

#sk_bubble div.sk_arrow div:nth-of-type(1) {
  border-top-color: var(--border) !important;
  border-bottom-color: var(--border) !important;
}

#sk_bubble div.sk_arrow div:nth-of-type(2) {
  border-top-color: var(--bg) !important;
  border-bottom-color: var(--bg) !important;
}

/* ---------- search ---------- */
#sk_status,
#sk_find {
  font-size: var(--font-size);
  border-color: var(--border);
}

.sk_theme kbd {
  background: var(--bg-dark);
  border-color: var(--border);
  box-shadow: none;
  color: var(--fg);
}

.sk_theme .feature_name span {
  color: var(--main-fg);
}

/* ---------- ace editor ---------- */
#sk_editor {
  background: var(--bg-dark) !important;
  height: 50% !important;
  /* remove this to restore the default editor size */
}

.ace_dialog-bottom {
  border-top: 1px solid var(--bg) !important;
}

.ace-chrome .ace_print-margin,
.ace_gutter,
.ace_gutter-cell,
.ace_dialog {
  background: var(--bg) !important;
}

.ace-chrome {
  color: var(--fg) !important;
}

.ace_gutter,
.ace_dialog {
  color: var(--fg) !important;
}

.ace_cursor {
  color: var(--fg) !important;
}

.normal-mode .ace_cursor {
  background-color: var(--fg) !important;
  border: var(--fg) !important;
  opacity: 0.7 !important;
}

.ace_marker-layer .ace_selection {
  background: var(--select) !important;
}

.ace_editor,
.ace_dialog span,
.ace_dialog input {
  font-family: var(--font);
  font-size: var(--font-size);
  font-weight: var(--font-weight);
}
`;
