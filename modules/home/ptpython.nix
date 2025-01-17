{ ... }:
{
  xdg.configFile."ptpython/config.py".text = # python
    ''
      from prompt_toolkit.filters import ViInsertMode
      from prompt_toolkit.key_binding.key_processor import KeyPress
      from prompt_toolkit.keys import Keys
      from prompt_toolkit.styles import Style

      from ptpython.layout import CompletionVisualisation

      __all__ = ["configure"]

      def configure(repl):
        repl.show_signature = True
        repl.show_docstring = True
        repl.highlight_matching_parenthesis = True
        repl.enable_mouse_support = False
        repl.complete_while_typing = True
        repl.enable_fuzzy_completion = False
        repl.enable_dictionary_completion = False

        repl.vi_mode = True

        # Enable the modal cursor (when using Vi mode). Other options are 'Block', 'Underline',  'Beam',  'Blink under', 'Blink block', and 'Blink beam'
        repl.cursor_shape_config = "Modal (vi)"

        # Paste mode. (When True, don't insert whitespace after new line.)
        repl.paste_mode = False

        # History Search.
        # When True, going back in history will filter the history on the records
        # starting with the current input. (Like readline.)
        # Note: When enable, please disable the `complete_while_typing` option.
        #       otherwise, when there is a completion available, the arrows will
        #       browse through the available completions instead of the history.
        repl.enable_history_search = False

        # Enable auto suggestions. (Pressing right arrow will complete the input,
        # based on the history.)
        repl.enable_auto_suggest = False

        # Enable open-in-editor. Pressing C-x C-e in emacs mode or 'v' in
        # Vi navigation mode will open the input in the current editor.
        repl.enable_open_in_editor = True

        # Enable system prompt. Pressing meta-! will display the system prompt.
        # Also enables Control-Z suspend.
        repl.enable_system_bindings = True

        # Ask for confirmation on exit.
        repl.confirm_exit = True

        # Enable input validation. (Don't try to execute when the input contains
        # syntax errors.)
        repl.enable_input_validation = True

        # Use this colorscheme for the code.
        # Ptpython uses Pygments for code styling, so you can choose from Pygments'
        # color schemes. See:
        # https://pygments.org/docs/styles/
        # https://pygments.org/demo/
        repl.use_code_colorscheme("github-dark")
        # A colorscheme that looks good on dark backgrounds is 'native':
        # repl.use_code_colorscheme("native")

        # Set color depth (keep in mind that not all terminals support true color).

        # repl.color_depth = "DEPTH_1_BIT"  # Monochrome.
        # repl.color_depth = "DEPTH_4_BIT"  # ANSI colors only.
        # repl.color_depth = "DEPTH_8_BIT"  # The default, 256 colors.
        repl.color_depth = "DEPTH_24_BIT"  # True color.

        # Min/max brightness
        repl.min_brightness = 0.0  # Increase for dark terminal backgrounds.
        repl.max_brightness = 1.0  # Decrease for light terminal backgrounds.

        repl.enable_syntax_highlighting = True

        # Get into Vi navigation mode at startup
        repl.vi_start_in_navigation_mode = False

        # Preserve last used Vi input mode between main loop iterations
        repl.vi_keep_last_used_mode = False

        # Install custom colorscheme named 'my-colorscheme' and use it.
        """
        repl.install_ui_colorscheme("my-colorscheme", Style.from_dict(_custom_ui_colorscheme))
        repl.use_ui_colorscheme("my-colorscheme")
        """
    '';
}
