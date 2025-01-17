{ ... }:
{
  xdg.configFile."ptpython/config.py".text = # python
    ''
      from prompt_toolkit.styles import Style


      __all__ = ["configure"]

      colors = {
        "rosewater": "#f5e0dc",
        "flamingo": "#f2cdcd",
        "pink": "#f5c2e7",
        "mauve": "#cba6f7",
        "red": "#f38ba8",
        "maroon": "#eba0ac",
        "peach": "#fab387",
        "yellow": "#f9e2af",
        "green": "#a6e3a1",
        "teal": "#94e2d5",
        "sky": "#89dceb",
        "sapphire": "#74c7ec",
        "blue": "#89b4fa",
        "lavender": "#b4befe",
        "text": "#cdd6f4",
        "subtext1": "#bac2de",
        "subtext0": "#a6adc8",
        "overlay2": "#9399b2",
        "overlay1": "#7f849c",
        "overlay0": "#6c7086",
        "surface2": "#585b70",
        "surface1": "#45475a",
        "surface0": "#313244",
        "base": "#1e1e2e",
        "mantle": "#181825",
        "crust": "#11111b",
      }
      style = {
        "pygments.comment": colors["overlay2"],
        "pygments.comment.hashbang": colors["overlay2"],
        "pygments.comment.multiline": colors["overlay2"],
        "pygments.comment.preproc": colors["pink"],
        "pygments.comment.single": colors["overlay2"],
        "pygments.comment.special": colors["overlay2"],
        "pygments.generic": colors["text"],
        "pygments.generic.deleted": colors["red"],
        "pygments.generic.emph": f"{colors["text"]} underline",
        "pygments.generic.error": colors["text"],
        "pygments.generic.heading": f"{colors["text"]} bold",
        "pygments.generic.inserted": f"{colors["text"]} bold",
        "pygments.generic.output": colors["overlay0"],
        "pygments.generic.prompt": colors["text"],
        "pygments.generic.strong": colors["text"],
        "pygments.generic.subheading": f"{colors["text"]} bold",
        "pygments.generic.traceback": colors["text"],
        "pygments.error": colors["text"],
        # `as`
        "pygments.keyword": colors["mauve"],
        "pygments.keyword.constant": colors["mauve"],
        "pygments.keyword.declaration": f"{colors["mauve"]} italic",
        # `from`, `import`
        "pygments.keyword.namespace": colors["mauve"],
        "pygments.keyword.pseudo": colors["pink"],
        "pygments.keyword.reserved": colors["mauve"],
        "pygments.keyword.type": colors["yellow"],
        "pygments.literal": colors["text"],
        "pygments.literal.date": colors["text"],
        # from xxx import NAME
        # NAME = NAME
        # NAME.NAME()
        "pygments.name": colors["text"],
        "pygments.name.attribute": colors["green"],
        # `len`, `print`
        "pygments.name.builtin": f"{colors["red"]} italic",
        # `self`
        "pygments.name.builtin.pseudo": colors["red"],
        # class Name.Class:
        "pygments.name.class": colors["yellow"],
        "pygments.name.constant": colors["text"],
        "pygments.name.decorator": colors["text"],
        "pygments.name.entity": colors["text"],
        "pygments.name.exception": colors["yellow"],
        # def __Name.Label__(
        "pygments.name.function": colors["blue"],
        "pygments.name.label": f"{colors["teal"]} italic",
        "pygments.name.namespace": colors["text"],
        "pygments.name.other": colors["text"],
        "pygments.name.tag": colors["blue"],
        "pygments.name.variable": f"{colors["text"]} italic",
        "pygments.name.variable.class": f"{colors["yellow"]} italic",
        "pygments.name.variable.global": f"{colors["text"]} italic",
        "pygments.name.variable.instance": f"{colors["text"]} italic",
        "pygments.number": colors["peach"],
        "pygments.number.bin": colors["peach"],
        "pygments.number.float": colors["peach"],
        "pygments.number.hex": colors["peach"],
        "pygments.number.integer": colors["peach"],
        "pygments.number.integer.long": colors["peach"],
        "pygments.number.oct": colors["peach"],
        # `=`
        "pygments.operator": colors["sky"],
        # `not`, `in`
        "pygments.operator.word": colors["mauve"],
        "pygments.other": colors["text"],
        # `(`, `)`, `,`, `[`, `]`, `:`
        "pygments.punctuation": colors["overlay2"],
        "pygments.string": colors["green"],
        "pygments.string.backtick": colors["green"],
        "pygments.string.char": colors["green"],
        "pygments.string.doc": colors["green"],
        "pygments.string.double": colors["green"],
        "pygments.string.escape": colors["pink"],
        "pygments.string.heredoc": colors["green"],
        "pygments.string.interpol": colors["green"],
        "pygments.string.other": colors["green"],
        "pygments.string.regex": colors["pink"],
        "pygments.string.single": colors["green"],
        "pygments.string.symbol": colors["red"],
        "pygments.text": colors["text"],
        "pygments.whitespace": colors["text"],
      }

      STYLE_NAME: str = "catppuccin-mocha"
      # PT_STYLE: Style = style_from_pygments_cls(MochaStyle)
      PT_STYLE: Style = Style.from_dict(style)


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
        # repl.use_code_colorscheme("github-dark")
        # A colorscheme that looks good on dark backgrounds is 'native':
        # repl.use_code_colorscheme("native")
        repl.install_ui_colorscheme(STYLE_NAME, PT_STYLE)
        repl.use_ui_colorscheme(STYLE_NAME)
        repl.install_code_colorscheme(STYLE_NAME, PT_STYLE)
        repl.use_code_colorscheme(STYLE_NAME)

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
    '';
}
