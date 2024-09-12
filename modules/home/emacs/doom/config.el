;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Clément POIRET"
      user-mail-address "poiret.clement@outlook.fr")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; See towards the end of the file for my theme-changing strategy based on time.
;;(setq doom-theme 'catppuccin)
;;(setq catppuccin-flavor 'mocha)


;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Sync/Notes/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(rainbow-delimiters-mode -1)
(setq-default global-whitespace-mode t)
(setq whitespace-style '(face spaces space-mark tabs tab-mark newline newline-mark trailing))

;; Change theme based on day/night
(defun my/set-theme-based-on-time ()
  "Set the theme based on the time of day."
  (let* ((hour (string-to-number (format-time-string "%H")))
         (daytime? (and (>= hour 9) (< hour 19))))
    (setq doom-theme 'catppuccin)
    (if daytime?
        (setq catppuccin-flavor 'latte)  ; Light theme
      (setq catppuccin-flavor 'mocha))   ; Dark theme
    (load-theme doom-theme t)))

;; Run now and check every hours
(my/set-theme-based-on-time)
(run-at-time "01:00" 3600 #'my/set-theme-based-on-time)

;; Fix copy paste on wayland
(when (getenv "WAYLAND_DISPLAY")
  (setq wl-copy-process nil)
  (defun wl-copy (text)
    (setq wl-copy-process (make-process :name "wl-copy"
                                        :buffer nil
                                        :command '("wl-copy" "-f" "-n")
                                        :connection-type 'pipe))
    (process-send-string wl-copy-process text)
    (process-send-eof wl-copy-process))
  (defun wl-paste ()
    (if (and wl-copy-process (process-live-p wl-copy-process))
        nil ; should return nil if we're the current paste owner
      (shell-command-to-string "wl-paste -n"))) ; | tr -d \r")))
  (setq interprogram-cut-function 'wl-copy)
  (setq interprogram-paste-function 'wl-paste))

(use-package! xclip
  :config
  (setq xclip-program "wl-copy")
  (setq xclip-select-enable-clipboard t)
  (setq xclip-mode t)
  (setq xclip-method (quote wl-copy)))

;; elysium
(use-package elysium
  :custom
  ;; Below are the default values
  (elysium-window-size 0.33) ; The elysium buffer will be 1/3 your screen
  (elysium-window-style 'vertical)) ; Can be customized to horizontal

;; gptel
(use-package! gptel
  :config
  (setq
   gptel-model "claude-3-5-sonnet-20240620"
   gptel-backend (gptel-make-anthropic "Claude"
                   :stream t :key "$ANTHROPIC_API_KEY")))

(use-package smerge-mode
  :ensure nil
  :hook
  (prog-mode . smerge-mode))

(use-package! lsp-bridge
  :config
  (setq lsp-bridge-enable-log nil)
  (setq lsp-bridge-nix-lsp-server :nil)
  (setq lsp-bridge-python-lsp-server :pylsp)
  (setq lsp-bridge-python-multi-lsp-server "pylsp_ruff")
  (setq acm-backend-lsp-enable-auto-import t)

  (map! :leader
        (:prefix ("c" . "code")
         :desc "LSP Code Action" "a" #'lsp-bridge-code-action
         :desc "LSP Find Definition" "h" #'lsp-bridge-find-def
         :desc "LSP Popup Documentation" "o" #'lsp-bridge-popup-documentation))

  (global-lsp-bridge-mode))

;; Because doing presentations in emacs is fun
(defun efs/presentation-setup ()
  (setq text-scale-mode-amount 3)
  (org-display-inline-images)
  (text-scale-mode 1))
(defun efs/presentation-end ()
  (text-scale-mode 0))

(use-package org-tree-slide
  :hook ((org-tree-slide-play . efs/presentation-setup)
         (org-tree-slide-stop . efs/presentation-end))
  :custom
  (org-tree-slide-in-effect t)
  (org-tree-slide-activate-message "Presentation started!")
  (org-tree-slide-deactivate-message "Presentation finished!")
  (org-tree-slide-header t)
  (org-tree-slide-breadcrumbs " > ")
  (org-image-actual-width nil))
