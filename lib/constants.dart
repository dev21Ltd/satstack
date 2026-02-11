// constants.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum Currency { USD, GBP, EUR, CAD, AUD, JPY, CNY }
enum TimeRange { DAY, WEEK, MONTH, YEAR }
enum Denomination { BTC, SATS }

const Color bitcoinOrange = Color(0xFFF7931A);

String currencyToString(Currency c) {
  switch (c) {
    case Currency.USD: return 'USD';
    case Currency.GBP: return 'GBP';
    case Currency.EUR: return 'EUR';
    case Currency.CAD: return 'CAD';
    case Currency.AUD: return 'AUD';
    case Currency.JPY: return 'JPY';
    case Currency.CNY: return 'CNY';
  }
}

String timeRangeToString(TimeRange t) {
  switch (t) {
    case TimeRange.DAY: return '1D';
    case TimeRange.WEEK: return '1W';
    case TimeRange.MONTH: return '1M';
    case TimeRange.YEAR: return '1Y';
  }
}

double parseNumberWithCommas(String value) {
  try {
    return NumberFormat().parse(value).toDouble();
  } catch (e) {
    return double.tryParse(value.replaceAll(',', '')) ?? 0;
  }
}

double satoshisToBtc(int sats) => sats / 100000000;
int btcToSatoshis(double btc) => (btc * 100000000).round();
String formatDenomination(double btcAmount, Denomination denomination) {
  if (denomination == Denomination.BTC) {
    final numberFormat = NumberFormat('#,##0.########');
    return '${numberFormat.format(btcAmount)} BTC';
  } else {
    final sats = btcToSatoshis(btcAmount);
    final numberFormat = NumberFormat('#,###');
    return '${numberFormat.format(sats)} sats';
  }
}