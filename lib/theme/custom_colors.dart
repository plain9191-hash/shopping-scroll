import 'package:flutter/material.dart';

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    this.sourceBrand,
    this.brand,
    this.sourceDiscount,
    this.discount,
    this.priceUp,
    this.priceDown,
  });

  final Color? sourceBrand;
  final Color? brand;
  final Color? sourceDiscount;
  final Color? discount;
  final Color? priceUp;
  final Color? priceDown;

  @override
  CustomColors copyWith({
    Color? sourceBrand,
    Color? brand,
    Color? sourceDiscount,
    Color? discount,
    Color? priceUp,
    Color? priceDown,
  }) {
    return CustomColors(
      sourceBrand: sourceBrand ?? this.sourceBrand,
      brand: brand ?? this.brand,
      sourceDiscount: sourceDiscount ?? this.sourceDiscount,
      discount: discount ?? this.discount,
      priceUp: priceUp ?? this.priceUp,
      priceDown: priceDown ?? this.priceDown,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      sourceBrand: Color.lerp(sourceBrand, other.sourceBrand, t),
      brand: Color.lerp(brand, other.brand, t),
      sourceDiscount: Color.lerp(sourceDiscount, other.sourceDiscount, t),
      discount: Color.lerp(discount, other.discount, t),
      priceUp: Color.lerp(priceUp, other.priceUp, t),
      priceDown: Color.lerp(priceDown, other.priceDown, t),
    );
  }

  // Optional
  @override
  String toString() => 'CustomColors('
      'sourceBrand: $sourceBrand, brand: $brand, '
      'sourceDiscount: $sourceDiscount, discount: $discount, '
      'priceUp: $priceUp, priceDown: $priceDown'
      ')';
}