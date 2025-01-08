// A very tridactyl-esque config file.

// Compatibility Prefix
const {
  Clipboard,
  Front,
  Hints,
  Normal,
  RUNTIME,
  Visual,
  aceVimMap,
  addSearchAlias,
  cmap,
  getClickableElements,
  imap,
  imapkey,
  iunmap,
  map,
  mapkey,
  readText,
  removeSearchAlias,
  tabOpenLink,
  unmap,
  unmapAllExcept,
  vmapkey,
  vunmap,
} = api;

// ---- Settings ----
Hints.setCharacters("asdfgyuiopqwertnmzxcvb");

settings.showModeStatus = true;
settings.defaultSearchEngine = "k";
settings.enableEmojiInsertion = false;
settings.hintAlign = "left";
settings.omnibarPosition = "bottom";
settings.omnibarSuggestion = true;
settings.focusFirstCandidate = true;
settings.focusAfterClosed = "last";
settings.scrollStepSize = 200;
settings.tabsThreshold = 0;
settings.modeAfterYank = "Normal";

// ---- Map -----
// --- Hints ---
// Open Multiple Links
map("<Alt-f>", "cf");

// Yank Link URL
map("<Alt-y>", "ya");
map("<Alt-u>", "ya");

// Open Hint in new tab
map("F", "C");

// --- Nav ---
// Open Clipboard URL in current tab
mapkey("p", "#4Open the clipboard's URL in the current tab", () => {
  Clipboard.read(function (response) {
    window.location.href = response.data;
  });
});

// Ctrl+Click on link
mapkey("<Alt-c>", "#4Ctrl+click on links (simulates Zen's Glance)", () => {
  Hints.create("*[href]", (element) => {
    const event = new MouseEvent("click", {
      ctrlKey: true,
      bubbles: true,
      cancelable: true,
      view: window,
    });
    element.dispatchEvent(event);
  });
});

map("gs", ";fs");

mapkey("g.", "#4Go to parent domain", () => {
  const subdomains = window.location.host.split(".");
  const parentDomain = (
    subdomains.length > 2 ? subdomains.slice(1) : subdomains
  ).join(".");
  const target = `${window.location.protocol}//${parentDomain}`;
  window.location.href = target;
});

// Open Clipboard URL in new tab
map("P", "cc");

// Open a URL in current tab
mapkey("o", "#8Open a URL in current tab", function () {
  Front.openOmnibar({ type: "URLs", tabbed: false });
});
mapkey("O", "#8Open a URL in a new tab", function () {
  Front.openOmnibar({ type: "URLs", tabbed: true });
});

// Choose a buffer/tab
map("b", "T");

// Edit current URL, and open in same tab
map("go", ";U");

// Edit current URL, and open in new tab
map("gO", ";u");

// History Back/Forward
map("H", "S");
map("L", "D");

// Scroll Page Down/Up
mapkey("<Ctrl-d>", "#2Scroll down", () => {
  Normal.scroll("pageDown");
});
mapkey("<Ctrl-u>", "#2Scroll up", () => {
  Normal.scroll("pageUp");
});
map("<Ctrl-b>", "U"); // scroll full page up
//map('<Ctrl-f>', 'P');  // scroll full page down -- looks like we can't overwrite browser-native binding

// View source code
mapkey("gc", "View page source", function () {
  RUNTIME("viewSource", { tab: { tabbed: true } });
});

mapkey("gS", "Open Firefox Config", () => {
  tabOpenLink("about:config");
});

// Open Chrome Flags
//mapkey("gF", "#12Open Chrome Flags", () => {
//  tabOpenLink("chrome://flags/");
//});

// --- Tabs ---
// Tab Delete/Undo
map("D", "x");
mapkey("d", "#3Close current tab", () => {
  RUNTIME("closeTab");
});
mapkey("u", "#3Restore closed tab", () => {
  RUNTIME("openLast");
});

// Move Tab Left/Right w/ one press
map(">", ">>");
map("<", "<<");

// Next/Prev Tab
map("K", "E");
map("J", "R");
map("<Alt-j>", "R");
map("<Alt-k>", "E");

// --- Misc ---
// Yank URL w/ one press (disables other yx binds)
map("y", "yy");

// Change focused frame
//map("gf", "w");

// ---- Unmap -----
// Proxy Stuff
unmap("spa");
unmap("spb");
unmap("spc");
unmap("spd");
unmap("sps");
unmap("cp");
unmap(";cp");
unmap(";ap");

// Emoji
iunmap(":");

// Misc
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

// ---- Search Engines -----
removeSearchAlias("b", "s");
removeSearchAlias("d", "s");
removeSearchAlias("g", "s");
removeSearchAlias("h", "s");
removeSearchAlias("w", "s");
removeSearchAlias("y", "s");
removeSearchAlias("s", "s");

addSearchAlias("k", "kagi", "https://kagi.com/search?q=", "s");
addSearchAlias("g", "github", "https://github.com/search?q=", "s");
addSearchAlias(
  "n",
  "nixp",
  "https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=",
  "s",
);
addSearchAlias("gh", "github", "https://github.com/search?q=", "s");

// theme
const hintsCss =
  "font-size: 12pt; font-family: 'TX02 Nerd Font', 'JetBrainsMono Nerd Font', 'Cascadia Code', 'Helvetica Neue', Helvetica, Arial, sans-serif; border: 0px; color: #b4befe !important; background: #1e1e2e !important; background-color: #1e1e2e !important";

//Hints.style(
//  "border: solid 2px #313244; color:#b4befe; background: initial; background-color: #1e1e2e;",
//);
//Hints.style(
//  "border: solid 2px #313244 !important; padding: 1px !important; color: #b4befe !important; background: #1e1e2e !important;",
//  "text",
//);
Hints.style(hintsCss);
Hints.style(hintsCss, "text");
Visual.style("marks", "background-color: #b4bef299;");
Visual.style("cursor", "background-color: #89b4fa;");

settings.theme = `
  #sk_editor {
    color: #cdd6f4;
    background: #1e1e2e !important;
    height: 50% !important;
    font-family: 'TX02 Nerd Font', monospace !important;
  }
  .sk_theme {
    background: #1e1e2e;
    color: #b4befe;
  }
  .sk_theme input {
    color: #b4befe;
  }
  .sk_theme .url {
    color: #89b4fa;
  }
  .sk_theme .annotation {
    color: #fab387;
  }
  .sk_theme kbd {
    background: #313244;
    color: #b4befe;
  }
  .sk_theme .frame {
    background: #181825;
  }
  .sk_theme .omnibar_highlight {
    color: #585b70;
  }
  .sk_theme .omnibar_folder {
    color: #b4befe;
  }
  .sk_theme .omnibar_timestamp {
    color: #74c7ec;
  }
  .sk_theme .omnibar_visitcount {
    color: #74c7ec;
  }
  .sk_theme .prompt, .sk_theme .resultPage {
    color: #b4befe;
  }
  .sk_theme .feature_name {
    color: #b4befe;
  }
  .sk_theme .separator {
    color: #45475a;
  }
  body {
    margin: 0;

    font-family: "TX02 Nerd Font", "JetBrainsMono Nerd Font", "Cascadia Code", "Helvetica Neue", Helvetica, Arial, sans-serif;
    font-size: 12px;
  }
  #sk_omnibar {
    overflow: hidden;
    position: fixed;
    width: 80%;
    max-height: 80%;
    left: 10%;
    text-align: left;
    box-shadow: 0px 2px 10px #21202e;
    z-index: 2147483000;
  }
  .sk_omnibar_middle {
    top: 10%;
    border-radius: 4px;
  }
  .sk_omnibar_bottom {
    bottom: 0;
    border-radius: 4px 4px 0px 0px;
  }
  #sk_omnibar span.omnibar_highlight {
    text-shadow: 0 0 0.01em;
  }
  #sk_omnibarSearchArea .prompt, #sk_omnibarSearchArea .resultPage {
    display: inline-block;
    font-size: 20px;
    width: auto;
  }
  #sk_omnibarSearchArea>input {
    display: inline-block;
    width: 100%;
    flex: 1;
    font-size: 20px;
    margin-bottom: 0;
    padding: 0px 0px 0px 0.5rem;
    background: transparent;
    border-style: none;
    outline: none;
  }
  #sk_omnibarSearchArea {
    display: flex;
    align-items: center;
    border-bottom: 1px solid #585b70;
  }
  .sk_omnibar_middle #sk_omnibarSearchArea {
    margin: 0.5rem 1rem;
  }
  .sk_omnibar_bottom #sk_omnibarSearchArea {
    margin: 0.2rem 1rem;
  }
  .sk_omnibar_middle #sk_omnibarSearchResult>ul {
    margin-top: 0;
  }
  .sk_omnibar_bottom #sk_omnibarSearchResult>ul {
    margin-bottom: 0;
  }
  #sk_omnibarSearchResult {
    max-height: 60vh;
    overflow: hidden;
    margin: 0rem 0.6rem;
  }
  #sk_omnibarSearchResult:empty {
    display: none;
  }
  #sk_omnibarSearchResult>ul {
    padding: 0;
  }
  #sk_omnibarSearchResult>ul>li {
    padding: 0.2rem 0rem;
    display: block;
    max-height: 600px;
    overflow-x: hidden;
    overflow-y: auto;
  }
  .sk_theme #sk_omnibarSearchResult>ul>li:nth-child(odd) {
    background: #181825;
  }
  .sk_theme #sk_omnibarSearchResult>ul>li.focused {
    background: #313244;
  }
  .sk_theme #sk_omnibarSearchResult>ul>li.window {
    border: 2px solid #585b70;
    border-radius: 8px;
    margin: 4px 0px;
  }
  .sk_theme #sk_omnibarSearchResult>ul>li.window.focused {
    border: 2px solid #89b4fa;
  }
  .sk_theme div.table {
    display: table;
  }
  .sk_theme div.table>* {
    vertical-align: middle;
    display: table-cell;
  }
  #sk_omnibarSearchResult li div.title {
    text-align: left;
  }
  #sk_omnibarSearchResult li div.url {
    font-weight: bold;
    white-space: nowrap;
  }
  #sk_omnibarSearchResult li.focused div.url {
    white-space: normal;
  }
  #sk_omnibarSearchResult li span.annotation {
    float: right;
  }
  #sk_omnibarSearchResult .tab_in_window {
    display: inline-block;
    padding: 5px;
    margin: 5px;
    box-shadow: 0px 2px 10px #21202e;
  }
  #sk_status {
    position: fixed;
    bottom: 0;
    right: 20%;
    z-index: 2147483000;
    padding: 4px 8px 0 8px;
    border-radius: 4px 4px 0px 0px;
    border: 1px solid #585b70;
    font-size: 12px;
  }
  #sk_status>span {
    line-height: 16px;
  }
  .expandRichHints span.annotation {
    padding-left: 4px;
    color: #fab387;
  }
  .expandRichHints .kbd-span {
    min-width: 30px;
    text-align: right;
    display: inline-block;
  }
  .expandRichHints kbd>.candidates {
    color: #b4befe;
    font-weight: bold;
  }
  .expandRichHints kbd {
    padding: 1px 2px;
  }
  #sk_find {
    border-style: none;
    outline: none;
  }
  #sk_keystroke {
    padding: 6px;
    position: fixed;
    float: right;
    bottom: 0px;
    z-index: 2147483000;
    right: 0px;
    background: #1e1e2e;
    color: #b4befe;
  }
  #sk_usage, #sk_popup, #sk_editor {
    overflow: auto;
    position: fixed;
    width: 80%;
    max-height: 80%;
    top: 10%;
    left: 10%;
    text-align: left;
    box-shadow: #21202e;
    z-index: 2147483298;
    padding: 1rem;
  }
  #sk_nvim {
    position: fixed;
    top: 10%;
    left: 10%;
    width: 80%;
    height: 30%;
  }
  #sk_popup img {
    width: 100%;
  }
  #sk_usage>div {
    display: inline-block;
    vertical-align: top;
  }
  #sk_usage .kbd-span {
    width: 80px;
    text-align: right;
    display: inline-block;
  }
  #sk_usage .feature_name {
    text-align: center;
    padding-bottom: 4px;
  }
  #sk_usage .feature_name>span {
    border-bottom: 2px solid #585b70;
  }
  #sk_usage span.annotation {
    padding-left: 32px;
    line-height: 22px;
  }
  #sk_usage * {
    font-size: 10pt;
  }
  kbd {
    white-space: nowrap;
    display: inline-block;
    padding: 3px 5px;
    font: 11px "TX02 Nerd Font", "JetBrains Mono NL", "Cascadia Code", "Helvetica Neue", Helvetica, Arial, sans-serif;
    line-height: 10px;
    vertical-align: middle;
    border: solid 1px #585b70;
    border-bottom-color: #585b70;
    border-radius: 3px;
    box-shadow: inset 0 -1px 0 #21202e;
  }
  #sk_banner {
    padding: 0.5rem;
    position: fixed;
    left: 10%;
    top: -3rem;
    z-index: 2147483000;
    width: 80%;
    border-radius: 0px 0px 4px 4px;
    border: 1px solid #585b70;
    border-top-style: none;
    text-align: center;
    background: #1e1e2e;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
    color: #cdd6f4 !important;
  }
  #sk_tabs {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: transparent;
    overflow: auto;
    z-index: 2147483000;
  }
  div.sk_tab {
    display: inline-flex;
    height: 28px;
    width: 202px;
    justify-content: space-between;
    align-items: center;
    flex-direction: row-reverse;
    border-radius: 3px;
    padding: 10px 20px;
    margin: 5px;
    background: -webkit-gradient(linear, left top, left bottom, color-stop(0%,#1e1e2e), color-stop(100%,#1e1e2e));
    box-shadow: 0px 3px 7px 0px #21202e;
  }
  div.sk_tab_wrap {
    display: inline-block;
    flex: 1;
  }
  div.sk_tab_icon {
    display: inline-block;
    vertical-align: middle;
  }
  div.sk_tab_icon>img {
    width: 18px;
  }
  div.sk_tab_title {
    width: 150px;
    display: inline-block;
    vertical-align: middle;
    font-size: 10pt;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
    padding-left: 5px;
    color: #b4befe;
  }
  div.sk_tab_url {
    font-size: 10pt;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
    color: #89b4fa;
  }
  div.sk_tab_hint {
    display: inline-block;
    float:right;
    font-size: 10pt;
    font-weight: bold;
    padding: 0px 2px 0px 2px;
    background: -webkit-gradient(linear, left top, left bottom, color-stop(0%,#1e1e2e), color-stop(100%,#1e1e2e));
    color: #b4befe;
    border: solid 1px #585b70;
    border-radius: 3px;
    box-shadow: #21202e;
  }
  #sk_tabs.vertical div.sk_tab_hint {
    position: initial;
    margin-inline: 0;
  }
  div.tab_rocket {
    display: none;
  }
  #sk_bubble {
    position: absolute;
    padding: 9px;
    border: 1px solid #585b70;
    border-radius: 4px;
    box-shadow: 0 0 20px #21202e;
    color: #b4befe;
    background-color: #1e1e2e;
    z-index: 2147483000;
    font-size: 14px;
  }
  #sk_bubble .sk_bubble_content {
    overflow-y: scroll;
    background-size: 3px 100%;
    background-position: 100%;
    background-repeat: no-repeat;
  }
  .sk_scroller_indicator_top {
    background-image: linear-gradient(#1e1e2e, transparent);
  }
  .sk_scroller_indicator_middle {
    background-image: linear-gradient(transparent, #1e1e2e, transparent);
  }
  .sk_scroller_indicator_bottom {
    background-image: linear-gradient(transparent, #1e1e2e);
  }
  #sk_bubble * {
    color: #b4befe !important;
  }
  div.sk_arrow>div:nth-of-type(1) {
    left: 0;
    position: absolute;
    width: 0;
    border-left: 12px solid transparent;
    border-right: 12px solid transparent;
    background: transparent;
  }
  div.sk_arrow[dir=down]>div:nth-of-type(1) {
    border-top: 12px solid #585b70;
  }
  div.sk_arrow[dir=up]>div:nth-of-type(1) {
    border-bottom: 12px solid #585b70;
  }
  div.sk_arrow>div:nth-of-type(2) {
    left: 2px;
    position: absolute;
    width: 0;
    border-left: 10px solid transparent;
    border-right: 10px solid transparent;
    background: transparent;
  }
  div.sk_arrow[dir=down]>div:nth-of-type(2) {
    border-top: 10px solid #b4befe;
  }
  div.sk_arrow[dir=up]>div:nth-of-type(2) {
    top: 2px;
    border-bottom: 10px solid #b4befe;
  }
  .ace_editor.ace_autocomplete {
    z-index: 2147483300 !important;
    width: 80% !important;
  }
  @media only screen and (max-width: 767px) {
    #sk_omnibar {
      width: 100%;
      left: 0;
    }
    #sk_omnibarSearchResult {
      max-height: 50vh;
      overflow: scroll;
    }
    .sk_omnibar_bottom #sk_omnibarSearchArea {
      margin: 0;
      padding: 0.2rem;
    }
  }
`;
