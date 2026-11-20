# Assert the compiled wire contract, including the unchanged length field.
def check($condition; $message):
  if $condition then . else error($message) end;

def enum_values($name):
  [.enumType[] | select(.name == $name) | .value[] | [.name, (.number // 0)]];

.file[]
| select(.name == "motif/data/model/v1/model.proto")
| check(
    ([.messageType[] | select(.name == "ModelUnitSettings") | .field[]
      | select(.name == "unit_symbol" or .name == "area_unit_symbol" or .name == "angle_unit_symbol")
      | [.name, .number, .type, .typeName]] == [
        ["unit_symbol", 5, "TYPE_ENUM", ".motif.data.model.v1.UnitSymbol"],
        ["area_unit_symbol", 6, "TYPE_ENUM", ".motif.data.model.v1.AreaUnitSymbol"],
        ["angle_unit_symbol", 7, "TYPE_ENUM", ".motif.data.model.v1.AngleUnitSymbol"]
      ]);
    "ModelUnitSettings symbol field numbers or types changed"
  )
| check(
    enum_values("UnitSymbol") == [
      ["UNIT_SYMBOL_UNSPECIFIED", 0], ["UNIT_SYMBOL_NONE", 1],
      ["UNIT_SYMBOL_MM", 2], ["UNIT_SYMBOL_CM", 3], ["UNIT_SYMBOL_DM", 4],
      ["UNIT_SYMBOL_M", 5], ["UNIT_SYMBOL_DAM", 6], ["UNIT_SYMBOL_HM", 7],
      ["UNIT_SYMBOL_KM", 8], ["UNIT_SYMBOL_FOOT_SINGLE_QUOTE", 9],
      ["UNIT_SYMBOL_FT", 10], ["UNIT_SYMBOL_LF", 11],
      ["UNIT_SYMBOL_INCH_DOUBLE_QUOTE", 12], ["UNIT_SYMBOL_IN", 13],
      ["UNIT_SYMBOL_YD", 14], ["UNIT_SYMBOL_FUR", 15], ["UNIT_SYMBOL_MI", 16]
    ];
    "Length symbol numbers changed"
  )
| check(
    enum_values("AreaUnitSymbol") == [
      ["AREA_UNIT_SYMBOL_UNSPECIFIED", 0], ["AREA_UNIT_SYMBOL_NONE", 1],
      ["AREA_UNIT_SYMBOL_SQUARE_MILLIMETER", 2], ["AREA_UNIT_SYMBOL_SQUARE_CENTIMETER", 3],
      ["AREA_UNIT_SYMBOL_SQUARE_METER", 4], ["AREA_UNIT_SYMBOL_SQUARE_KILOMETER", 5],
      ["AREA_UNIT_SYMBOL_SQUARE_INCH", 6], ["AREA_UNIT_SYMBOL_SQUARE_FOOT", 7],
      ["AREA_UNIT_SYMBOL_SQUARE_YARD", 8], ["AREA_UNIT_SYMBOL_SQUARE_FURLONG", 9],
      ["AREA_UNIT_SYMBOL_ACRE", 10], ["AREA_UNIT_SYMBOL_SQUARE_MILE", 11]
    ];
    "Area symbol numbers changed"
  )
| check(
    enum_values("AngleUnitSymbol") == [
      ["ANGLE_UNIT_SYMBOL_UNSPECIFIED", 0], ["ANGLE_UNIT_SYMBOL_NONE", 1],
      ["ANGLE_UNIT_SYMBOL_DEGREE", 2], ["ANGLE_UNIT_SYMBOL_RADIAN", 3]
    ];
    "Angle symbol numbers changed"
  )
| true
