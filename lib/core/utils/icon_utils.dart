import 'package:flutter/material.dart';

class IconUtils {
  static const IconData defaultIcon = Icons.category_rounded;

  static final Map<int, IconData> _iconRegistry = {
    Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
    Icons.directions_car_rounded.codePoint: Icons.directions_car_rounded,
    Icons.coffee_rounded.codePoint: Icons.coffee_rounded,
    Icons.shopping_bag_rounded.codePoint: Icons.shopping_bag_rounded,
    Icons.home_rounded.codePoint: Icons.home_rounded,
    Icons.medical_services_rounded.codePoint: Icons.medical_services_rounded,
    Icons.account_balance_wallet_rounded.codePoint:
        Icons.account_balance_wallet_rounded,
    Icons.computer_rounded.codePoint: Icons.computer_rounded,
    Icons.trending_up_rounded.codePoint: Icons.trending_up_rounded,
    Icons.trending_down_rounded.codePoint: Icons.trending_down_rounded,
    Icons.shopping_cart_rounded.codePoint: Icons.shopping_cart_rounded,
    Icons.local_gas_station_rounded.codePoint: Icons.local_gas_station_rounded,
    Icons.flight_rounded.codePoint: Icons.flight_rounded,
    Icons.school_rounded.codePoint: Icons.school_rounded,
    Icons.fitness_center_rounded.codePoint: Icons.fitness_center_rounded,
    Icons.pets_rounded.codePoint: Icons.pets_rounded,
    Icons.phone_android_rounded.codePoint: Icons.phone_android_rounded,
    Icons.wifi_rounded.codePoint: Icons.wifi_rounded,
    Icons.electric_bolt_rounded.codePoint: Icons.electric_bolt_rounded,
    Icons.water_drop_rounded.codePoint: Icons.water_drop_rounded,
    Icons.movie_rounded.codePoint: Icons.movie_rounded,
    Icons.sports_esports_rounded.codePoint: Icons.sports_esports_rounded,
    Icons.card_giftcard_rounded.codePoint: Icons.card_giftcard_rounded,
    Icons.savings_rounded.codePoint: Icons.savings_rounded,
    Icons.attach_money_rounded.codePoint: Icons.attach_money_rounded,
    Icons.work_rounded.codePoint: Icons.work_rounded,
    Icons.build_rounded.codePoint: Icons.build_rounded,
    Icons.receipt_long_rounded.codePoint: Icons.receipt_long_rounded,
    Icons.credit_card_rounded.codePoint: Icons.credit_card_rounded,
    Icons.payment_rounded.codePoint: Icons.payment_rounded,
    Icons.sell_rounded.codePoint: Icons.sell_rounded,
    Icons.inventory_2_rounded.codePoint: Icons.inventory_2_rounded,
    Icons.local_grocery_store_rounded.codePoint:
        Icons.local_grocery_store_rounded,
    Icons.local_cafe_rounded.codePoint: Icons.local_cafe_rounded,
    Icons.fastfood_rounded.codePoint: Icons.fastfood_rounded,
    Icons.health_and_safety_rounded.codePoint: Icons.health_and_safety_rounded,
    Icons.local_hospital_rounded.codePoint: Icons.local_hospital_rounded,
    Icons.local_pharmacy_rounded.codePoint: Icons.local_pharmacy_rounded,
    Icons.directions_bus_rounded.codePoint: Icons.directions_bus_rounded,
    Icons.local_taxi_rounded.codePoint: Icons.local_taxi_rounded,
    Icons.commute_rounded.codePoint: Icons.commute_rounded,
    Icons.category_rounded.codePoint: Icons.category_rounded,
  };

  /// Safely resolves a constant IconData from database codePoint.
  /// Guarantees font icon tree-shaking compatibility in release builds.
  static IconData getIconData(
    int codePoint, {
    String fontFamily = 'MaterialIcons',
  }) {
    return _iconRegistry[codePoint] ?? defaultIcon;
  }
}
