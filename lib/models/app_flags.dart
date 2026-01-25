class AppFlags {
  final String version;
  final bool hideMagazines;
  final bool hideNewspapers;

  const AppFlags({
    this.version = "",
    this.hideMagazines = false,
    this.hideNewspapers = false,
  });

  factory AppFlags.fromMap(Map<String, dynamic> map) {
    return AppFlags(
      version: (map["version"] ?? "").toString(),
      hideMagazines:
          map["hide_magazines"] == true || map["hideMagazines"] == true,
      hideNewspapers:
          map["hide_newspapers"] == true || map["hideNewspapers"] == true,
    );
  }

  AppFlags copyWith({
    String? version,
    bool? hideMagazines,
    bool? hideNewspapers,
  }) {
    return AppFlags(
      version: version ?? this.version,
      hideMagazines: hideMagazines ?? this.hideMagazines,
      hideNewspapers: hideNewspapers ?? this.hideNewspapers,
    );
  }

  static const AppFlags defaults = AppFlags();
}
