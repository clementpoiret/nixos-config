{
  config,
  pkgs,
  lib,
  ...
}:
let
  readSecret = subPath: builtins.readFile config.sops.secrets."accounts/${subPath}".path;
  readPort = subPath: builtins.fromJSON (readSecret subPath);

  commonPatterns = [
    "*"
    "!All Mail"
    "![Gmail]/All Mail"
  ];

  mkAccount =
    {
      id,
      primary ? false,
      authMethod ? "password",
      timeout ? 120,
      pipelineDepth ? 1,
      extraPatterns ? [ ],
      useImapStartTls ? false,
      useSmtpStartTls ? false,
      copyToSent ? true,
      trashFolder ? "Trash",
      draftsFolder ? "Drafts",
      sentFolder ? "Sent",
    }:
    let
      isOAuth = authMethod == "xoauth2";
      rn = readSecret "realName";
      name = readSecret "${id}/name";
    in
    {
      "${name}" = {
        inherit primary;
        address = readSecret "${id}/address";
        realName = rn;
        userName = readSecret "${id}/userName";
        passwordCommand = readSecret "${id}/passwordCommand";

        folders = {
          inbox = "Inbox";
          trash = trashFolder;
          drafts = draftsFolder;
          sent = if copyToSent then sentFolder else null;
        };

        imap = {
          host = readSecret "${id}/imap/host";
          port = readPort "${id}/imap/port";
          tls.enable = true;
          tls.useStartTls = useImapStartTls;
          authentication = if isOAuth then "xoauth2" else "plain";
        };

        smtp = {
          host = readSecret "${id}/smtp/host";
          port = readPort "${id}/smtp/port";
          tls.enable = true;
          tls.useStartTls = useSmtpStartTls;
          authentication = if isOAuth then "xoauth2" else "plain";
        };

        mbsync = {
          enable = true;
          create = "maildir";
          expunge = "both";
          patterns = commonPatterns ++ extraPatterns;
          extraConfig.account = {
            PipelineDepth = pipelineDepth;
            Timeout = timeout;
            AuthMechs = if isOAuth then "XOAUTH2" else "LOGIN";
          };
        };

        msmtp = {
          enable = true;
          extraConfig = {
            auth = if isOAuth then "xoauth2" else "on";
          };
        };

        aerc.enable = true;
        aerc.extraAccounts = {
          source = "maildir://${config.home.homeDirectory}/Maildir/${name}";
          outgoing = "${pkgs.msmtp}/bin/msmtp -a ${name}";
          default = "Inbox";
          trash = trashFolder;
          check-mail = "5m";
          check-mail-cmd = "${config.programs.mbsync.package}/bin/mbsync ${name}";
          folders-sort = "Inbox,INBOX,Starred,Sent,Sent Items,[Gmail]/Sent Mail,[Gmail]/Messages envoyés,Drafts,[Gmail]/Brouillons,Archive,Archives,Trash,Bin,Junk,[Gmail]/Corbeille";
        };
      };
    };

  myAccounts = lib.mkMerge [
    (mkAccount {
      id = "pers1";
      timeout = 220;
      primary = true;
      extraPatterns = [ "!Labels*" ];
      useImapStartTls = true;
      useSmtpStartTls = true;
      copyToSent = false;
    })
    (mkAccount {
      id = "pers2";
      timeout = 220;
      pipelineDepth = 2;
      useImapStartTls = false;
      useSmtpStartTls = false;
      copyToSent = true;
    })
    (mkAccount {
      id = "pers3";
      authMethod = "xoauth2";
      timeout = 220;
      pipelineDepth = 3;
      useImapStartTls = false;
      useSmtpStartTls = true;
      copyToSent = false;
    })
    (mkAccount {
      id = "work1";
      authMethod = "xoauth2";
      timeout = 220;
      pipelineDepth = 3;
      useImapStartTls = false;
      useSmtpStartTls = false;
      copyToSent = false;
      trashFolder = "[Gmail]/Corbeille";
      draftsFolder = "[Gmail]/Brouillons";
      sentFolder = "[Gmail]/Messages envoyés";
    })
  ];
in
{
  home.packages = with pkgs; [
    aerc
    bat
    catimg
    pandoc
    w3m
    xdg-utils
  ];
  accounts.email.accounts = myAccounts;

  programs.mbsync = {
    enable = true;
    package = pkgs.isync.override { withCyrusSaslXoauth2 = true; };
  };
  programs.msmtp.enable = true;

  xdg.configFile."mailcap".text = ''
    text/html; w3m -I %{charset} -T text/html -dump; copiousoutput;
  '';

  programs.aerc = {
    enable = true;
    extraConfig = {
      general = {
        unsafe-accounts-conf = true;
        log-file = "~/.config/aerc/aerc.log";
        log-level = "trace";
        empty-subject-warning = true;
        enable-osc8 = true;
      };

      ui = {
        mouse-enabled = true;
        sidebar-width = 30;
        auto-mark-read = false;
        border-char-vertical = "│";
        border-char-horizontal = "─";
        column-separator = "\"  \"";
        dirlist-delay = "500ms";
        dirlist-tree = true;
        empty-message = "Tumbleweed";
        fuzzy-complete = true;

        # Icons
        icon-attachment = " "; # nf-fa-paperclip
        icon-new = " "; # nf-fa-envelope
        icon-old = " "; # nf-fa-envelope_open
        icon-flagged = " "; # nf-fa-flag
        icon-draft = " "; # nf-fa-pencil
        icon-marked = " "; # nf-fa-check_circle
        icon-replied = " "; # nf-fa-reply

        index-columns = "date<8,name<17,subject<*,flags<4";
        pinned-tab-marker = "*";
        styleset-name = "rose-pine";
        threading-enabled = true;
        timestamp-format = "06-01-02 15:04";
      };

      statusline = {
        status-columns = "left<*,center>=,right>*";
        column-left = "{{.Folder}}";
        column-center = "{{.PendingKeys}} {{.TrayInfo}} {{.StatusInfo}}";
        column-right = "{{if gt (len .From) 0}}{{(index .From 0).Address}}{{else}}No Sender{{end}} {{.Size | humanReadable}}";
        separator = " | ";
      };

      openers = {
        "text/html" = "${pkgs.xdg-utils}/bin/xdg-open";
        "application/pdf" = "${pkgs.xdg-utils}/bin/xdg-open";
        "image/*" = "${pkgs.xdg-utils}/bin/xdg-open";
      };

      multipart-converters = {
        "text/html" = "${pkgs.pandoc}/bin/pandoc -f gfm -t html --standalone";
      };

      compose = {
        editor = "hx";
        header-layout = "To,Cc,Bcc,From,Subject";
        reply-to-self = true;
        no-attachment-warning = true;
        file-picker-cmd = "find . -maxdepth 2 -not -path '*/.*' | fzf";
      };

      filters = ''
        text/plain=${pkgs.aerc}/libexec/aerc/filters/colorize
        text/calendar=${pkgs.aerc}/libexec/aerc/filters/calendar
        message/delivery-status=${pkgs.aerc}/libexec/aerc/filters/colorize
        message/rfc822=${pkgs.aerc}/libexec/aerc/filters/colorize

        text/html=${pkgs.aerc}/libexec/aerc/filters/html

        text/*=test -n \"$AERC_FILENAME\" && ${pkgs.bat}/bin/bat -fP --file-name=\"$AERC_FILENAME\" || ${pkgs.aerc}/libexec/aerc/filters/colorize
        .headers=${pkgs.aerc}/libexec/aerc/filters/colorize
      '';

      triggers = {
        new-email = "exec notify-send 'New email from %n' '%s'";
      };
    };

    extraBinds = {
      global = {
        "<C-t>" = ":term<Enter>";
        "?" = ":help keys<Enter>";
        "gt" = ":next-tab<Enter>";
        "gT" = ":prev-tab<Enter>";
        "H" = ":prev-tab<Enter>";
        "L" = ":next-tab<Enter>";
        "ZZ" = ":prompt 'Quit? ' quit<Enter>";
      };

      messages = {
        "!" = ":term<space>";
        "$" = ":term<space>";
        "/" = ":search<space>";
        "<C-b>" = ":prev 100%<Enter>";
        "<C-d>" = ":next 50%<Enter>";
        "<C-f>" = ":next 100%<Enter>";
        "<C-i>" = ":vsplit - <Enter>";
        "<C-l>" = ":clear<Enter>";
        "<C-o>" = ":vsplit + <Enter>";
        "<C-r>" = ":check-mail<Enter>";
        "<C-u>" = ":prev 50%<Enter>";
        "<C-w>" = ":vsplit<Enter>";
        "<Down>" = ":next<Enter>";
        "<Enter>" = ":view<Enter>";
        "<Esc>" = ":clear<Enter>";
        "<PgDn>" = ":next 100%<Enter>";
        "<PgUp>" = ":prev 100%<Enter>";
        "<Up>" = ":prev<Enter>";
        "c" = ":cf<space>";
        "dd" = ":delete<Enter>";
        "tu" = ":unsubscribe<Enter>";
        "E" = ":compose<Enter>";
        "ea" = ":reply -a<Enter>";
        "ee" = ":compose<Enter>";
        "eF" = ":forward -a<Enter>";
        "ef" = ":forward<Enter>";
        "eR" = ":reply -aq<Enter>";
        "er" = ":reply -q<Enter>";
        "F" = ":filter<space>";
        "fa" = ":filter -a<space>";
        "fb" = ":filter -b<space>";
        "fc" = ":filter -c<space>";
        "fd" = ":filter -d<space>";
        "ff" = ":filter -f<space> \"{{index (.From | emails) 0}}\" <Enter>";
        "fF" = ":filter -f<space>";
        "fr" = ":filter -r<space>";
        "fs" = ":filter -H<space> subject:\"{{.SubjectBase}}\" <Enter>";
        "fS" = ":filter -H<space> subject:<Space>";
        "ft" = ":filter -t<space>";
        "fu" = ":filter -u<space>";
        "G" = ":select -1<Enter>";
        "gg" = ":select 0<Enter>";
        "i" = ":compose<Enter>";
        "J" = ":next-folder<Enter>";
        "j" = ":next<Enter>";
        "K" = ":prev-folder<Enter>";
        "k" = ":prev<Enter>";
        "l" = ":view<Enter>";
        "mm" = ":mark -v<Enter>";
        "mt" = ":mark -t<Enter>";
        "md" = ":mark -d<Enter>";
        "mu" = ":unread<Enter>";
        "n" = ":next-result<Enter>";
        "N" = ":prev-result<Enter>";
        "O" = ":compose<Enter>";
        "o" = ":reply -q<Enter>";
        "pa" = ":archive flat<Enter>";
        "pf" = ":move<space>";
        "sA" = ":sort -r arrival<Enter>";
        "sa" = ":sort arrival<Enter>";
        "sC" = ":sort -r cc<Enter>";
        "sc" = ":sort cc<Enter>";
        "sD" = ":sort -r date<Enter>";
        "sd" = ":sort date<Enter>";
        "sF" = ":sort -r from<Enter>";
        "sf" = ":sort from<Enter>";
        "sR" = ":sort -r read<Enter>";
        "sr" = ":sort read<Enter>";
        "sS" = ":sort -r subject<Enter>";
        "ss" = ":sort subject<Enter>";
        "sT" = ":sort -r to<Enter>";
        "st" = ":sort to<Enter>";
        "sZ" = ":sort -r size<Enter>";
        "sz" = ":sort size<Enter>";
        "ta" = ":flag -ta<Enter>";
        "tr" = ":read -t<Enter>";
        "ts" = ":flag -tx Seen<Enter>";
        "tt" = ":toggle-threads<Enter>";
        "V" = ":mark -V<Enter>";
        "vv" = ":mark -v<Enter>";
        "va" = ":mark -a<Enter>";
        "vt" = ":mark -t<Enter>";
        "vT" = ":mark -T<Enter>";
        "<Space>" = ":mark -t<Enter>:next<Enter>";
        "yy" = ":copy<space>";
        "yf" = ":pipe -b echo \"{{index (.From | emails) 0}}\" | wl-copy";
        "ys" = ":pipe -b echo \"{{.Subject}}\" | wl-copy";
        "yd" = ":pipe -b echo \"{{.Date}}\" | wl-copy";
        "zC" = ":collapse-folder<Enter>";
        "zc" = ":collapse<Enter>";
        "zO" = ":expand-folder<Enter>";
        "zo" = ":open-thread<Enter>";
        "|" = ":pipe<space>";
      };

      "messages:folder=Drafts" = {
        "<Enter>" = ":recall<Enter>";
      };

      view = {
        "<C-i>" = ":toggle-key-passthrough<Enter>";
        "<C-j>" = ":next<Enter>";
        "<C-k>" = ":prev<Enter>";
        "dd" = ":delete<Enter>";
        "ea" = ":reply -a<Enter>";
        "ee" = ":reply <Enter>";
        "eF" = ":forward -a<Enter>";
        "ef" = ":forward<Enter>";
        "eQ" = ":reply -a -q<Enter>";
        "eq" = ":reply -q<Enter>";
        "F" = ":forward -a<Enter>";
        "f" = ":forward<Enter>";
        "gl" = ":open-link <space>";
        "h" = ":close<Enter>";
        "i" = ":reply<Enter>";
        "I" = ":toggle-key-passthrough<Enter>";
        "j" = ":next-part<Enter>";
        "k" = ":prev-part<Enter>";
        "l" = ":open<Enter>";
        "o" = ":reply -aq<Enter>";
        "O" = ":reply -q<Enter>";
        "pa" = ":archive flat<Enter>";
        "pf" = ":move<space>";
        "q" = ":close<Enter>";
        "ra" = ":reply -a<Enter>";
        "rq" = ":reply -q<Enter>";
        "rr" = ":reply -aq<Enter>";
        "th" = ":toggle-headers<Enter>";
        "w" = ":save<space>";
        "x" = ":delete<Enter>";
        "|" = ":pipe<space>";
      };

      "view::passthrough" = {
        "$noinherit" = "true";
        "$ex" = "<C-x>";
        "<Esc>" = ":toggle-key-passthrough<Enter>";
      };

      compose = {
        "$ex" = "<C-x>";
        "$noinherit" = "true";
        "<A-h>" = ":switch-account -p<Enter>";
        "<A-l>" = ":switch-account -n<Enter>";
        "<backtab>" = ":prev-field<Enter>";
        "<C-h>" = ":prev-tab<Enter>";
        "<C-j>" = ":next-field<Enter>";
        "<C-k>" = ":prev-field<Enter>";
        "<C-l>" = ":next-tab<Enter>";
        "<tab>" = ":next-field<Enter>";
      };

      "compose::editor" = {
        "$noinherit" = "true";
        "$ex" = "<C-x>";
        "<C-k>" = ":prev-field<Enter>";
        "<C-j>" = ":next-field<Enter>";
        "<C-h>" = ":prev-tab<Enter>";
        "<C-l>" = ":next-tab<Enter>";
      };

      "compose::review" = {
        "m" = ":multipart text/html<Enter>";
        "w" = ":send<Enter>";
        "s" = ":send<Enter>";
        "ZZ" = ":abort<Enter>";
        "q" = ":abort<Enter>";
        "v" = ":preview<Enter>";
        "p" = ":postpone<Enter>";
        "d" = ":discard<Enter>";
        "D" = ":discard abort<Enter>";
        "e" = ":edit<Enter>";
        "aa" = ":attach<space>";
        "ad" = ":detach<space>";
      };

      terminal = {
        "$noinherit" = "true";
        "$ex" = "<C-x>";
        "<C-h>" = ":prev-tab<Enter>";
        "<C-l>" = ":next-tab<Enter>";
      };
    };
  };

  xdg.configFile."aerc/stylesets/rose-pine".text = ''
    # Rosé Pine Theme for Aerc
    # All natural pine, faux fur and a bit of soho vibes for the classy minimalist
    # Save as ~/.config/aerc/stylesets/rose-pine

    # Base styling
    default.fg=#9ccfd8
    default.bg=#191724

    success.fg=#31748f
    error.fg=#eb6f92
    warning.fg=#f6c177

    title.bg=#26233a
    title.fg=#c4a7e7

    header.fg=#c4a7e7

    spinner.fg=#6e6a86

    part_filename.fg=#f6c177
    part_mimetype.fg=#c4a7e7

    # Global selection
    *.selected.fg=#191724
    *.selected.bg=#ebbcba
    *.selected.bold=true

    # Message list
    msglist_default.fg=#9ccfd8
    msglist_default.bg=#1f1d2e
    msglist_unread.fg=#e0def4
    msglist_unread.bold=true
    msglist_read.fg=#6e6a86
    msglist_flagged.fg=#f6c177
    msglist_flagged.bold=true
    msglist_deleted.bg=#eb6f92
    msglist_deleted.fg=#191724
    msglist_deleted.bold=true
    msglist_marked.fg=#191724
    msglist_marked.bg=#31748f
    msglist_marked.bold=true

    # Status bar
    statusline_*.bold=true
    statusline_default.fg=#9ccfd8
    statusline_default.bg=#191724
    statusline_error.fg=#191724
    statusline_error.bg=#eb6f92
    statusline_success.fg=#191724
    statusline_success.bg=#31748f

    # Completion
    completion_default.fg=#9ccfd8
    completion_default.bg=#1f1d2e
    completion_gutter.bg=#26233a
    completion_description.bg=#26233a

    # Scrollbars
    *_pill.fg=#191724
    *_pill.bg=#6e6a86

    # Border
    border.fg=#191724
    border.bg=#191724

    # Tab
    tab.bg=#191724
    tab.selected.fg=#ebbcba
    tab.selected.bg=#191724
    tab.selected.bold=true

    [viewer]
    url.fg=#c4a7e7
    url.underline=true
    header.bold=true
    signature.dim=true
    diff_meta.bold=true
    diff_chunk.fg=#c4a7e7
    diff_chunk_func.fg=#c4a7e7
    diff_chunk_func.bold=true
    diff_add.fg=#524f67
    diff_del.fg=#eb6f92
    quote_*.fg=#908caa
    quote_1.fg=#21202e
  '';
}
