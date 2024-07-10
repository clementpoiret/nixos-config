{ inputs, pkgs, ... }:
{
  programs.qutebrowser = {
    enable = true;
    searchEngines = {
      "DEFAULT" = "https://kagi.com/search?q={}";
      "d" = "https://duckduckgo.com/?q={}&ia=web";
      "p" = "https://perplexity.ai/search?q={}";
      "g" = "https://google.com/search?q={}";
      "n" = "https://mynixos.com/search?q={}";
      "nixo" = "https://search.nixos.org/options?channel=unstable&query={}";
      "nixp" = "https://search.nixos.org/packages?channel=unstable&query={}";
      "gt" = "https://github.com/search?q={}&type=repositories";
    };
    
    settings = {
      url = {
        default_page =
          "https://kagi.com/smallweb/";
        start_pages =
          [ "https://kagi.com/smallweb/" ];
        yank_ignored_parameters = [
          "ref"
          "utm_source"
          "utm_medium"
          "utm_campaign"
          "utm_term"
          "utm_content"
          "utm_name"
        ];
      };

      content = {
        autoplay = false;
        blocking.enabled = true;
        blocking.hosts.block_subdomains = true;
        blocking.method = "both";
        blocking.whitelist = [];
        canvas_reading = false;
        cookies.accept = "no-3rdparty";
              dns_prefetch = true;
        headers.accept_language = "en-US,en;q=0.9";
        headers.do_not_track = true;
        headers.referer = "same-domain";
        headers.user_agent = "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {qt_key}/{qt_version} {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}";
        javascript.clipboard = "none";
        javascript.enabled = false;
        pdfjs = false;
      };

      downloads = {
        position = "bottom";
        remove_finished = 5000;
      };

      hints = {
        auto_follow = "unique-match";
        auto_follow_timeout = 700;
      };

      input = {
        insert_mode.auto_enter = true;
        insert_mode.auto_leave = true;
        insert_mode.auto_load = true;
      };

      tabs.background = true;

      auto_save = {
        session = false;
        interval = 15000;
      };

      qt.highdpi = true;
    }; 

    keyBindings = {
      normal = {
        "sp" = "spawn --userscript qutepocket";
        # "E" = "spawn floorp '{url}'";
        "E" = "spawn firefox-developer-edition '{url}'";
        "M" = "hint links spawn mpv '{hint-url}'";
        "P" = "open -w https://pass.proton.me/u/0/";
        "\\\\" = "mode-enter passthrough";
      };
      insert = {
        "<Ctrl-h>" = "fake-key <Backspace>";
        "<Ctrl-a>" = "fake-key <Home>";
        "<Ctrl-e>" = "fake-key <End>";
        "<Ctrl-b>" = "fake-key <Left>";
        "<Mod1-b>" = "fake-key <Ctrl-Left>";
        "<Ctrl-f>" = "fake-key <Right>";
        "<Mod1-f>" = "fake-key <Ctrl-Right>";
        "<Ctrl-p>" = "fake-key <Up>";
        "<Ctrl-n>" = "fake-key <Down>";
        "<Ctrl-d>" = "fake-key <Delete>";
        "<Mod1-d>" = "fake-key <Ctrl-Delete>";
        "<Ctrl-w>" = "fake-key <Ctrl-Backspace>";
        "<Ctrl-u>" = "fake-key <Shift-Home><Delete>";
        "<Ctrl-k>" = "fake-key <Shift-End><Delete>";
        "<Ctrl-x><Ctrl-e>" = "open-editor";
      };
    };

    extraConfig = ''
      ALLOW_JAVASCRIPT_WEBSITES = (
        "qute://*/*",
        "devtools://*",
        "chrome://*/*",
        "chrome-devtools://*",
        r"*://127.0.0.1/*",
        r"*://localhost/*",
        r"*://*.amazon.com/*",
        r"*://*.archlinux.org/*",
        r"*://*.controld.com/*",
        r"*://*.duckduckgo.com/*",
        r"*://*.evanchen.cc/*",
        r"*://*.element.io/*",
        r"*://*.gather.town/*",
        r"*://*.github.com/*",
        r"*://*.kagi.com/*",
        r"*://*.linear.app/*",
        r"*://*.mit.edu/*",
        r"*://*.myaccount.google.com/*",
        r"*://*.nextdns.io/*",
        r"*://*.nixos.org/*",
        r"*://*.notion.so/*",
        r"*://*.notion.site/*",
        r"*://*.perplexity.ai/*",
        r"*://*.proton.me/*",
        r"*://*.overleaf.com/*",  # their documentation is admittedly not bad
        r"*://*.readthedocs.io/*",
        r"*://*.reddit.com/*",
        r"*://*.redditinc.com/*",
        r"*://*.scaleway.com/*",
        r"*://*.scholar-inbox.com/*",
        r"*://*.slack.com/*",
        r"*://*.stackexchange.com/*",
        r"*://*.stripe.com/*",
        r"*://*.supabase.com/*",
        r"*://*.usaco.org/*",
        r"*://*.wikipedia.org/*",
        r"*://*.wolframalpha.com/*",
        r"*://*.wikidata.org/*",
        r"*://*.writefull.com/*",
        r"*://*.youtube.com/*",
        r"*://accounts.google.com/*",
        r"*://artofproblemsolving.com/*",
        r"*://arxiv.org/*",
        r"*://calendar.google.com/*",
        r"*://mail.google.com/*",
        r"*://meet.google.com/*",
        r"*://calendly.com/*",
        r"*://docs.google.com/*",
        r"*://drive.google.com/*",
        r"*://gitlab.com/*",
        r"*://login.artofproblemsolving.com/*",
        r"*://mathoverflow.net/*",
        r"*://stackoverflow.com/*",
      )
      for site in ALLOW_JAVASCRIPT_WEBSITES:
        config.set("content.javascript.enabled", True, site)

      BLOCKING_FILTERS = [
        "https://big.oisd.nl",
        "https://raw.githubusercontent.com/easylist/listefr/master/liste_fr.txt",
        "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt",
      ]
      c.content.blocking.adblock.lists = BLOCKING_FILTERS

      config.set("content.canvas_reading", True, r"*://*.gather.town/*")

      config.set('content.cookies.accept', 'all', r"*://*.overleaf.com/*")
      config.set('content.cookies.accept', 'all', r"*://*.perplexity.ai/*")
      config.set('content.cookies.accept', 'all', r"*://*.reddit.com/*")
      config.set('content.cookies.accept', 'all', r"*://*.redditinc.com/*")
      config.set('content.cookies.accept', 'all', r"*://*.writefull.com/*")
      config.set('content.cookies.accept', 'all', 'chrome-devtools://*')
      config.set('content.cookies.accept', 'all', 'devtools://*')

      config.set(
        'content.headers.user_agent',
        'Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}',
        'https://web.whatsapp.com/')
      config.set(
        'content.headers.user_agent',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        r"*://*.proton.me/*")
      config.set(
        'content.headers.user_agent',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        r"*://*.reddit.com/*")
      config.set(
        'content.headers.user_agent',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        r"*://*.perplexity.ai/*")
      config.set(
        'content.headers.user_agent',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        r"*://*.redditinc.com/*")
      config.set('content.headers.user_agent',
        'Mozilla/5.0 ({os_info}; rv:90.0) Gecko/20100101 Firefox/90.0',
        'https://accounts.google.com/*')

      config.set('content.images', True, 'chrome-devtools://*')
      config.set('content.images', True, 'devtools://*')

      config.set('content.javascript.clipboard', 'access-paste', r"*://*.proton.me/*")

      config.set('content.local_content_can_access_remote_urls', True,
        'file:///home/clementpoiret/.local/share/qutebrowser/userscripts/*')
      config.set('content.local_content_can_access_file_urls', False,
           'file:///home/clementpoiret/.local/share/qutebrowser/userscripts/*')

      c.spellcheck.languages = ["en-US", "fr-FR"]

      c.aliases = {
        'w': 'session-save',
        'q': 'close',
        'qa': 'quit',
        'wq': 'quit --save',
        'wqa': 'quit --save'
      }
    '';
  };

  home.packages = (with pkgs; [
    inputs.qbpm.packages.${system}.qbpm
  ]);

  xdg.mimeApps = {
    enable = true;

    associations.added = {
      "text/html" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/http" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/https" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/about" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/unknown" = [ "org.qutebrowser.qutebrowser.desktop" ];
    };
    defaultApplications = {
      "text/html" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/http" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/https" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/about" = [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/unknown" = [ "org.qutebrowser.qutebrowser.desktop" ];
    };
  };
}
