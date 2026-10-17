import 'calculator_keypad.dart';

// Keep less-common conversions in the palette rather than permanent keypad rows.
final endianButtons = <CalcButtonConfig>[
  for (final name in ['htons', 'ntohs', 'htonl', 'ntohl'])
    CalcButtonConfig(
      displayText: name,
      insertText: '$name(',
      tooltip: '${name.endsWith('s') ? 16 : 32}-bit network ↔ host',
    ),
  for (final width in [16, 32, 64]) ...[
    CalcButtonConfig(
      displayText: 'bswap$width',
      insertText: 'bswap$width(',
      tooltip: 'Reverse bytes; unsigned $width-bit result',
    ),
    CalcButtonConfig(
      displayText: 'htobe$width',
      insertText: 'htobe$width(',
      tooltip: '$width-bit host to big-endian',
    ),
    CalcButtonConfig(
      displayText: 'be${width}toh',
      insertText: 'be${width}toh(',
      tooltip: '$width-bit big-endian to host',
    ),
    CalcButtonConfig(
      displayText: 'htole$width',
      insertText: 'htole$width(',
      tooltip: '$width-bit host to little-endian',
    ),
    CalcButtonConfig(
      displayText: 'le${width}toh',
      insertText: 'le${width}toh(',
      tooltip: '$width-bit little-endian to host',
    ),
  ],
];
