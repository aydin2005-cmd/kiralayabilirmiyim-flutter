enum ApplicationType {
  homeRental,
  carRental,
}

extension ApplicationTypeX on ApplicationType {
  String get apiValue {
    switch (this) {
      case ApplicationType.homeRental:
        return 'home_rental';
      case ApplicationType.carRental:
        return 'car_rental';
    }
  }

  String get label {
    switch (this) {
      case ApplicationType.homeRental:
        return 'Ev Kiralama';
      case ApplicationType.carRental:
        return 'Araç Kiralama';
    }
  }
}
