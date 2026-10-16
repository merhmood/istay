/// A bolder-stroke, drop-in replacement for `LucideIcons`.
///
/// Every icon this app actually uses, re-pointed at Lucide's 500-weight
/// glyphs (2.5px stroke) instead of the package default's 400-weight
/// (2.0px) - the same codepoint, just a heavier variant of the same
/// font, decoded and confirmed against the package's own embedded SVG
/// previews rather than assumed. Every file that used to import
/// `package:lucide_icons_flutter/lucide_icons.dart` imports this file
/// instead (hiding the original `LucideIcons`), so every existing
/// `LucideIcons.foo` call site picks up the bolder stroke with no
/// change to the call site itself.
///
/// Generated once against lucide_icons_flutter 3.1.20's own icon set -
/// if a newly-used icon has no entry here, add it following the same
/// pattern (its 500-weight codepoint is identical to its base one).
library;

import 'package:flutter/widgets.dart' show IconData;

class LucideIcons {
  LucideIcons._();

  static const IconData arrowLeft = IconData(
    57416,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData arrowUpRight = IconData(
    57421,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData award = IconData(
    57423,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData badgeCheck = IconData(
    57921,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData ban = IconData(
    57425,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData banknote = IconData(
    57426,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData barChart3 = IconData(
    58019,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData bath = IconData(
    58027,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData batteryCharging = IconData(
    57428,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData bedDouble = IconData(
    58050,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData building = IconData(
    57804,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData building2 = IconData(
    58000,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData calendar = IconData(
    57443,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData calendarCheck = IconData(
    58039,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData calendarDays = IconData(
    58041,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData calendarX2 = IconData(
    58047,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData check = IconData(
    57452,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData checkCircle = IconData(
    57468,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData chevronDown = IconData(
    57453,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData chevronLeft = IconData(
    57454,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData chevronRight = IconData(
    57455,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData circleCheck = IconData(
    57894,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData circleDashed = IconData(
    58544,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData circleHelp = IconData(
    57474,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData clock = IconData(
    57479,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData coffee = IconData(
    57494,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData cookingPot = IconData(
    58756,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData copy = IconData(
    57502,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData creditCard = IconData(
    57514,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData doorOpen = IconData(
    58326,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData dumbbell = IconData(
    58273,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData eye = IconData(
    57530,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData eyeOff = IconData(
    57531,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData fan = IconData(
    58233,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData fileText = IconData(
    57548,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData flame = IconData(
    57554,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData hash = IconData(
    57583,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData heart = IconData(
    57586,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData heartHandshake = IconData(
    58071,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData hourglass = IconData(
    58006,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData house = IconData(
    57589,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData imagePlus = IconData(
    57847,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData images = IconData(
    58820,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData inbox = IconData(
    57591,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData info = IconData(
    57593,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData landmark = IconData(
    57914,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData laptop = IconData(
    57805,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData layoutGrid = IconData(
    57599,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData locate = IconData(
    57818,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData lockKeyhole = IconData(
    58673,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData logIn = IconData(
    57613,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData logOut = IconData(
    57614,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData luggage = IconData(
    58058,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData mail = IconData(
    57615,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData mapPin = IconData(
    57617,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData mapPinCheck = IconData(
    58895,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData mapPinOff = IconData(
    58022,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData mapPinned = IconData(
    58685,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData menu = IconData(
    57621,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData messageSquare = IconData(
    57623,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData minus = IconData(
    57628,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData minusCircle = IconData(
    57470,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData navigation = IconData(
    57635,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData palmtree = IconData(
    57985,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData parkingCircle = IconData(
    58313,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData pencil = IconData(
    57849,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData percent = IconData(
    57650,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData phone = IconData(
    57651,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData plugZap = IconData(
    58460,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData plus = IconData(
    57661,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData plusCircle = IconData(
    57473,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData receipt = IconData(
    58323,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData route = IconData(
    58686,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData search = IconData(
    57681,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData send = IconData(
    57682,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData share = IconData(
    57686,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData shieldCheck = IconData(
    57855,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData slidersHorizontal = IconData(
    58010,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData snowflake = IconData(
    57701,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData sparkles = IconData(
    58386,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData star = IconData(
    57718,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData tent = IconData(
    57895,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData trash2 = IconData(
    57742,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData trees = IconData(
    58101,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData triangleAlert = IconData(
    57747,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData type = IconData(
    57752,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData umbrella = IconData(
    57753,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData user = IconData(
    57759,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData userRound = IconData(
    58472,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData users = IconData(
    57764,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData video = IconData(
    57765,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData wallet = IconData(
    57860,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData washingMachine = IconData(
    58768,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData waves = IconData(
    57987,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData wifi = IconData(
    57774,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData x = IconData(
    57778,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData zap = IconData(
    57780,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
  static const IconData zoomIn = IconData(
    57782,
    fontFamily: 'Lucide500',
    fontPackage: 'lucide_icons_flutter',
  );
}
