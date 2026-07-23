from goromail.cli import parse_loseit_nutrients

# Trimmed but structurally faithful Nutrient Summary from a real Lose It! email.
NUTRIENT_HTML = """
<table>
  <tr>
    <td>Nutrient Summary</td>
    <td>% Calories</td>
  </tr>
  <tr>
    <td style="a">\t
      Fat
    </td>
    <td>
    47g
    </td>
    <td align="right">
      51.5%
    </td>
  <tr>
    <td style="a">\t
      &nbsp;&nbsp;
      Saturated Fat
    </td>
    <td>
    9g
    </td>
    <td align="right">
    -
    </td>
  <tr>
    <td style="a">\t
      Carbohydrates
    </td>
    <td>
    46g
    </td>
    <td align="right">
      22.7%
    </td>
  <tr>
    <td style="a">\t
      &nbsp;&nbsp;
      Fiber
    </td>
    <td>
    5g
    </td>
    <td align="right">
    -
    </td>
  <tr>
    <td style="a">\t
      Protein
    </td>
    <td>
    53g
    </td>
    <td align="right">
      25.8%
    </td>
</table>
"""


def test_parses_macros_and_fat_pct():
    assert parse_loseit_nutrients(NUTRIENT_HTML) == (47, 46, 53, 51.5)


def test_no_table_returns_none():
    assert parse_loseit_nutrients("<html>no summary here</html>") is None


def test_missing_macro_returns_none():
    html = NUTRIENT_HTML.replace("Protein", "Prot31n")  # break the Protein row label
    assert parse_loseit_nutrients(html) is None


def test_saturated_fat_not_mistaken_for_fat():
    # Remove the real Fat row; only "Saturated Fat" remains -> Fat grams missing -> None
    html = NUTRIENT_HTML.replace("      Fat\n", "      Removed\n")
    assert parse_loseit_nutrients(html) is None
