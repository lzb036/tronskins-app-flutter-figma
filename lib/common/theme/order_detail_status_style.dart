import 'package:flutter/material.dart';

const List<Color> kOrderDetailStatusCardGradientColors = <Color>[
  Color(0xFF10B981),
  Color(0xFF059669),
];

const List<BoxShadow> kOrderDetailStatusCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color.fromRGBO(6, 78, 59, 0.16),
    blurRadius: 18,
    offset: Offset(0, 10),
  ),
  BoxShadow(
    color: Color.fromRGBO(6, 78, 59, 0.10),
    blurRadius: 6,
    offset: Offset(0, 4),
  ),
];

const Color kOrderDetailStatusTextProcessing = Color(0xFF7C2D12);
const Color kOrderDetailStatusTextSuccess = Color(0xFF064E3B);
const Color kOrderDetailStatusTextSettlement = Color(0xFF1E3A8A);
const Color kOrderDetailStatusTextDanger = Color(0xFF7F1D1D);
const Color kOrderDetailStatusTextReady = Color(0xFF115E59);
const Color kOrderDetailStatusTextNeutral = Color(0xFF334155);
