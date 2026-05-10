extension NumClamp on num {
  num clamp(num lower, num upper) {
    if (this < lower) return lower;
    if (this > upper) return upper;
    return this;
  }
}
