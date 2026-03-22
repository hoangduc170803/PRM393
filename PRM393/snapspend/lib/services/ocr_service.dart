import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'llama_service.dart';

class OcrService {
  final LlamaService _llamaService = LlamaService();

  /// Get access to the Llama service for model management
  LlamaService get llamaService => _llamaService;

  /// Preprocesses an image for better OCR results
  /// - Converts to grayscale
  /// - Ensures DPI is at least 300
  /// - Applies contrast enhancement
  /// - Applies sharpening
  Future<String> preprocessImage(
    String imagePath, {
    bool runInBackground = true,
  }) async {
    try {
      // Compute output path on the UI isolate (path_provider is MethodChannel-based).
      final tempDir = await getTemporaryDirectory();
      final processedPath = path.join(
        tempDir.path,
        'processed_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (runInBackground) {
        // Offload CPU-heavy image decoding/resizing/contrast work to a background isolate.
        await compute(_preprocessImageCompute, <String, String>{
          'inputPath': imagePath,
          'outputPath': processedPath,
        });
      } else {
        _preprocessImageSync(inputPath: imagePath, outputPath: processedPath);
      }

      print('Preprocessed image saved to: $processedPath');
      return processedPath;
    } catch (e) {
      print('Error preprocessing image: $e');
      rethrow;
    }
  }

  /// Apply adaptive thresholding for better text recognition
  // ignore: unused_element
  img.Image _adaptiveThreshold(img.Image image) {
    final threshold = img.Image(width: image.width, height: image.height);

    const blockSize = 15;
    const c = 10;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = pixel.r.toInt();

        // Calculate local mean
        var sum = 0;
        var count = 0;

        for (var dy = -blockSize ~/ 2; dy <= blockSize ~/ 2; dy++) {
          for (var dx = -blockSize ~/ 2; dx <= blockSize ~/ 2; dx++) {
            final nx = x + dx;
            final ny = y + dy;

            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final neighborPixel = image.getPixel(nx, ny);
              sum += neighborPixel.r.toInt();
              count++;
            }
          }
        }

        final mean = sum ~/ count;
        final localThreshold = mean - c;

        // Apply threshold
        final newValue = gray > localThreshold ? 255 : 0;
        threshold.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }

    return threshold;
  }

  /// Apply bilateral filter to reduce noise while preserving edges
  /// This is especially useful for screen photos and low-quality images
  // ignore: unused_element
  img.Image _bilateralFilter(img.Image image) {
    // Create output image
    final filtered = img.Image(width: image.width, height: image.height);

    const int diameter = 5; // Filter diameter
    const double sigmaColor = 50.0; // Filter sigma in color space
    const double sigmaSpace = 50.0; // Filter sigma in coordinate space

    final radius = diameter ~/ 2;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        double sumWeights = 0.0;
        double sumValue = 0.0;

        final centerPixel = image.getPixel(x, y);
        final centerValue = centerPixel.r.toDouble();

        // Apply bilateral filter in neighborhood
        for (var dy = -radius; dy <= radius; dy++) {
          for (var dx = -radius; dx <= radius; dx++) {
            final nx = x + dx;
            final ny = y + dy;

            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final neighborPixel = image.getPixel(nx, ny);
              final neighborValue = neighborPixel.r.toDouble();

              // Calculate spatial distance
              final spatialDist = (dx * dx + dy * dy).toDouble();
              final spatialWeight = _gaussian(
                spatialDist,
                sigmaSpace * sigmaSpace,
              );

              // Calculate color distance
              final colorDist = (centerValue - neighborValue).abs();
              final colorWeight = _gaussian(colorDist, sigmaColor * sigmaColor);

              // Combined weight
              final weight = spatialWeight * colorWeight;

              sumWeights += weight;
              sumValue += weight * neighborValue;
            }
          }
        }

        final filteredValue = (sumValue / sumWeights).round().clamp(0, 255);
        filtered.setPixel(
          x,
          y,
          img.ColorRgb8(filteredValue, filteredValue, filteredValue),
        );
      }
    }

    return filtered;
  }

  /// Gaussian function for bilateral filter
  double _gaussian(double x, double sigma) {
    return (1.0 / (2.0 * math.pi * sigma)) * math.exp(-x / (2.0 * sigma));
  }

  /// Scans a receipt image with Tesseract OCR
  /// Returns the extracted text
  Future<String> scanReceipt(
    String imagePath, {
    bool preprocessInBackground = true,
    bool ocrInBackground = true,
  }) async {
    try {
      print('Starting OCR scan for: $imagePath');

      // Preprocess the image for better OCR results
      print('Preprocessing image...');
      final processedPath = await preprocessImage(
        imagePath,
        runInBackground: preprocessInBackground,
      );

      // Perform OCR on the preprocessed image
      print('Running Tesseract OCR...');
      final ocrArgs = <String, String>{
        "psm":
            "3", // Fully automatic page segmentation (works best for mixed content)
        "oem": "1", // Neural nets LSTM engine only
        "preserve_interword_spaces": "1",
      };

      String text;
      RootIsolateToken? rootToken;
      if (ocrInBackground) {
        // RootIsolateToken.instance can throw if bindings weren't initialized.
        try {
          rootToken = RootIsolateToken.instance;
        } catch (e) {
          rootToken = null;
        }
      }

      if (ocrInBackground && rootToken != null) {
        // NOTE: Calling MethodChannel plugins from background isolates requires
        // BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken).
        // If this fails on a given platform/plugin version, we'll fall back to
        // running on the main isolate.
        try {
          text = await compute(_tesseractOcrCompute, <String, Object?>{
            'rootToken': rootToken,
            'imagePath': processedPath,
            'language': 'vie+eng',
            'args': ocrArgs,
          });
        } catch (e) {
          print('Background OCR failed, falling back to main isolate: $e');
          text = await FlutterTesseractOcr.extractText(
            processedPath,
            language:
                'vie+eng', // Vietnamese first for better character recognition
            args: ocrArgs,
          );
        }
      } else {
        text = await FlutterTesseractOcr.extractText(
          processedPath,
          language:
              'vie+eng', // Vietnamese first for better character recognition
          args: ocrArgs,
        );
      }

      // Post-process the OCR text to fix common mistakes
      final cleanedText = _postProcessOcrText(text);

      print('${imagePath} OCR Text:\n$cleanedText');

      // Clean up the preprocessed temporary file
      try {
        await File(processedPath).delete();
        print('Cleaned up temporary preprocessed file');
      } catch (e) {
        print('Warning: Could not delete temporary file: $e');
      }

      return cleanedText;
    } catch (e) {
      print('Error scanning receipt: $e');
      rethrow;
    }
  }

  /// Post-process OCR text to fix common recognition errors
  String _postProcessOcrText(String text) {
    String cleaned = text;

    // Fix common Vietnamese currency misrecognitions
    // "um" is often misread "VNĐ" (VND)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+\.?\d*)\s*um\b', caseSensitive: false),
      (match) => '${match.group(1)} VNĐ',
    );

    // Fix common number confusions in Vietnamese context
    cleaned = cleaned.replaceAll(RegExp(r'099/-'), '0997-');

    // Fix "O" (letter O) misread as "0" (zero) in transaction IDs
    // Only in specific contexts where it's clearly a letter
    cleaned = cleaned.replaceAll(RegExp(r'AQR0O'), 'AQRO0');

    // Normalize whitespace (but preserve line breaks)
    // Replace multiple spaces with single space
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    // Clean up spaces around line breaks
    cleaned = cleaned.replaceAll(RegExp(r' *\n *'), '\n');
    // Remove multiple consecutive line breaks
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }

  /// Extract structured data from receipt text
  /// Returns a map with receipt information
  Map<String, dynamic> parseReceiptText(String text) {
    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final result = <String, dynamic>{
      'rawText': text,
      'merchant': '',
      'date': '',
      'total': 0.0,
      'items': <Map<String, dynamic>>[],
    };

    // Try to find merchant name (usually first few lines)
    if (lines.isNotEmpty) {
      result['merchant'] = lines[0].trim();
    }

    // Pattern for prices: $XX.XX or XX.XX
    final pricePattern = RegExp(r'\$?\s*(\d+\.\d{2})');

    // Pattern for dates
    final datePattern = RegExp(
      r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})|(\d{4}[-/]\d{1,2}[-/]\d{1,2})',
    );

    double? maxPrice;

    for (final line in lines) {
      // Look for date
      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch != null && result['date'].isEmpty) {
        result['date'] = dateMatch.group(0) ?? '';
      }

      // Look for prices
      final priceMatches = pricePattern.allMatches(line);
      for (final match in priceMatches) {
        final priceStr = match.group(1);
        if (priceStr != null) {
          final price = double.tryParse(priceStr);
          if (price != null) {
            // Track the highest price as potential total
            if (maxPrice == null || price > maxPrice) {
              maxPrice = price;
            }

            // Try to extract item name (text before the price)
            final itemName = line.substring(0, match.start).trim();
            if (itemName.isNotEmpty) {
              result['items'].add({'name': itemName, 'price': price});
            }
          }
        }
      }

      // Look for total amount (keywords: total, amount, balance)
      if (line.toLowerCase().contains('total') ||
          line.toLowerCase().contains('amount') ||
          line.toLowerCase().contains('balance')) {
        final priceMatch = pricePattern.firstMatch(line);
        if (priceMatch != null) {
          final totalStr = priceMatch.group(1);
          if (totalStr != null) {
            result['total'] = double.tryParse(totalStr) ?? 0.0;
          }
        }
      }
    }

    // If no explicit total found, use the highest price
    if (result['total'] == 0.0 && maxPrice != null) {
      result['total'] = maxPrice;
    }

    return result;
  }

  /// Extract structured receipt data using Llama AI model
  /// Returns a JSON object with sender, recipient, amount, and time
  /// Falls back to regex extraction if LLM fails
  Future<Map<String, dynamic>> extractReceiptDataWithLlama({
    required String receiptText,
    Function(String)? onStatusUpdate,
    Function(String)? onTextUpdate,
  }) async {
    try {
      // Update status
      if (onStatusUpdate != null) {
        onStatusUpdate('Extracting receipt data with AI...');
      }

      // Check if Llama model is ready
      if (!_llamaService.isModelReady) {
        print('⚠️ Llama model not ready, falling back to regex extraction');
        if (onStatusUpdate != null) {
          onStatusUpdate('Using fallback extraction...');
        }
        return extractFromVietnameseReceipt(receiptText);
      }

      // Create a detailed prompt for the LLM
      final prompt = _buildReceiptExtractionPrompt(receiptText);

      print('Using Llama AI for receipt data extraction');
      print('Prompt length: ${prompt.length} characters');

      // Generate response with Llama
      String generatedJson = '';
      await _llamaService.generateText(
        prompt: prompt,
        onStatusUpdate: (status) {
          print('Llama status: $status');
          if (onStatusUpdate != null) {
            onStatusUpdate(status);
          }
        },
        onTextUpdate: (text) {
          generatedJson = text;
          if (onTextUpdate != null) {
            onTextUpdate(text);
          }
        },
        maxTokens: 150, // Reduced - just need simple JSON
        contextSize: 2048, // Increased for longer OCR text
        batchSize: 2048, // Match contextSize to allow single-batch decode
        streamOutput: false,
        threads: 4,
      );

      print('Generated response:\n$generatedJson');

      // Parse and validate JSON response
      final extractedData = _extractJsonFromResponse(generatedJson);

      if (extractedData == null) {
        print('Failed to parse LLM response, falling back to regex');
        if (onStatusUpdate != null) {
          onStatusUpdate('Using fallback extraction...');
        }
        return extractFromVietnameseReceipt(receiptText);
      }

      // Validate we got some data
      if (extractedData['amount'] == 0.0 &&
          extractedData['sender'] == 'N/A' &&
          extractedData['time'] == 'N/A') {
        print('LLM extracted empty data, falling back to regex');
        return extractFromVietnameseReceipt(receiptText);
      }

      if (onStatusUpdate != null) {
        onStatusUpdate('Extraction complete!');
      }

      print('Successfully extracted data with Llama AI');
      return extractedData;
    } catch (e) {
      print('Error in extractReceiptDataWithLlama: $e');
      print('Falling back to regex extraction');

      if (onStatusUpdate != null) {
        onStatusUpdate('Using fallback extraction...');
      }

      // Fallback to regex extraction
      return extractFromVietnameseReceipt(receiptText);
    }
  }

  /// Build a detailed prompt for receipt extraction
  String _buildReceiptExtractionPrompt(String receiptText) {
    return '''Extract receipt information from the following Vietnamese text and output ONLY valid JSON with English keys.

Receipt OCR text:
$receiptText

Rules:
1. Output MUST be valid JSON only
2. Use ONLY English keys: "sender", "recipient", "amount", "time"
3. NO Vietnamese text in keys
4. NO explanations or extra text
5. If field not found, use "N/A"

Example output:
{"sender":"Nguyễn Văn A","recipient":"Công ty TNHH B","amount":81000.00,"time":"18/10/2025 19:45"}

Now extract and output JSON:''';
  }

  /// Extract JSON object from LLM response text
  Map<String, dynamic>? _extractJsonFromResponse(String response) {
    // Clean response - remove any markdown code blocks
    String cleaned = response.trim();

    // Remove markdown code fences
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // Remove any text before the first {
    final firstBrace = cleaned.indexOf('{');
    if (firstBrace > 0) {
      cleaned = cleaned.substring(firstBrace);
    }

    // Remove any text after the last }
    final lastBrace = cleaned.lastIndexOf('}');
    if (lastBrace >= 0 && lastBrace < cleaned.length - 1) {
      cleaned = cleaned.substring(0, lastBrace + 1);
    }

    // Debug: Print raw bytes to check encoding
    print('🔍 Raw response bytes (first 100):');
    final bytes = utf8.encode(
      cleaned.substring(0, cleaned.length > 100 ? 100 : cleaned.length),
    );
    print(
      '   ${bytes.take(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    print(
      'Attempting to parse: ${cleaned.substring(0, cleaned.length > 200 ? 200 : cleaned.length)}...',
    );

    // Try to find JSON object in the response - handle nested braces and Thai text
    // Use a more flexible pattern that handles Unicode (Thai characters)
    final jsonPattern = RegExp(
      r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}',
      multiLine: true,
    );
    final matches = jsonPattern.allMatches(cleaned);

    // First try: look for complete JSON objects
    for (final match in matches) {
      try {
        final jsonStr = match.group(0);
        if (jsonStr != null && jsonStr.length > 10) {
          // Basic sanity check - should have key fields
          if (jsonStr.contains('sender') ||
              jsonStr.contains('amount') ||
              jsonStr.contains('time')) {
            print(
              '✓ Found potential JSON: ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...',
            );
            final parsed = json.decode(jsonStr);
            if (parsed is Map<String, dynamic>) {
              final validated = _validateAndNormalizeReceiptData(parsed);
              if (validated != null) {
                return validated;
              }
              // If validation failed, continue to next match
              print('Validation failed, trying next match...');
            }
          }
        }
      } catch (e) {
        print('JSON parse failed for match: $e');
        // Continue to next match
        continue;
      }
    }

    // Second try: look for JSON-like structure even if malformed
    final lines = cleaned.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('{') && trimmed.contains('}')) {
        try {
          final parsed = json.decode(trimmed);
          if (parsed is Map<String, dynamic>) {
            print('✓ Parsed JSON from line');
            final validated = _validateAndNormalizeReceiptData(parsed);
            if (validated != null) {
              return validated;
            }
          }
        } catch (e) {
          continue;
        }
      }
    }

    // Third try: try to extract JSON from the entire response
    try {
      final parsed = json.decode(cleaned);
      if (parsed is Map<String, dynamic>) {
        print('✓ Parsed JSON from entire response');
        final validated = _validateAndNormalizeReceiptData(parsed);
        if (validated != null) {
          return validated;
        }
      }
    } catch (e) {
      // Not valid JSON
      print('Full response not valid JSON');
    }

    // Fourth try: If model outputs numbered list, try to parse it
    print('Attempting to parse numbered list format...');
    final extractedData = _parseNumberedListFormat(cleaned);
    if (extractedData != null) {
      print('✓ Successfully parsed from numbered list');
      return extractedData;
    }

    print('All JSON extraction attempts failed');
    return null;
  }

  /// Parse numbered list format that the model sometimes outputs
  /// Example: "1. sender: GrabPay\n2. recipient: N/A\n3. amount: 62.00\n4. time: ..."
  Map<String, dynamic>? _parseNumberedListFormat(String text) {
    try {
      final result = <String, dynamic>{
        'sender': 'N/A',
        'recipient': 'N/A',
        'amount': 0.0,
        'time': 'N/A',
      };

      // Patterns to extract field values from numbered lists
      final senderPattern = RegExp(
        r'(?:sender|merchant)[:\s]+["' +
            r"']?" +
            r'([^"' +
            r"'" +
            r'\n]+?)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );
      final recipientPattern = RegExp(
        r'recipient[:\s]+["' +
            r"']?" +
            r'([^"' +
            r"'" +
            r'\n]+?)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );
      final amountPattern = RegExp(
        r'amount(?:_in_currency)?[:\s]+["' +
            r"']?" +
            r'(\d+\.?\d*)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );
      final timePattern = RegExp(
        r'(?:time|date_time)[:\s]+["' +
            r"']?" +
            r'([^"' +
            r"'" +
            r'\n]+?)["' +
            r"']?" +
            r'(?:\n|$)',
        caseSensitive: false,
      );

      bool foundAny = false;

      // Extract sender
      final senderMatch = senderPattern.firstMatch(text);
      if (senderMatch != null) {
        result['sender'] = senderMatch.group(1)?.trim() ?? 'N/A';
        foundAny = true;
      }

      // Extract recipient
      final recipientMatch = recipientPattern.firstMatch(text);
      if (recipientMatch != null) {
        result['recipient'] = recipientMatch.group(1)?.trim() ?? 'N/A';
        foundAny = true;
      }

      // Extract amount
      final amountMatch = amountPattern.firstMatch(text);
      if (amountMatch != null) {
        final amountStr = amountMatch.group(1);
        if (amountStr != null) {
          result['amount'] = double.tryParse(amountStr) ?? 0.0;
          foundAny = true;
        }
      }

      // Extract time
      final timeMatch = timePattern.firstMatch(text);
      if (timeMatch != null) {
        result['time'] = timeMatch.group(1)?.trim() ?? 'N/A';
        foundAny = true;
      }

      // Only return if we found at least some data
      return foundAny ? _validateAndNormalizeReceiptData(result) : null;
    } catch (e) {
      print('Error parsing numbered list: $e');
      return null;
    }
  }

  /// Validate and normalize the receipt data structure
  /// Rejects template/placeholder responses
  Map<String, dynamic>? _validateAndNormalizeReceiptData(
    Map<String, dynamic> data,
  ) {
    final sender = data['sender']?.toString() ?? 'N/A';
    final recipient = data['recipient']?.toString() ?? 'N/A';
    final time = data['time']?.toString() ?? 'N/A';

    // Check for placeholder/template text that the model shouldn't return
    final placeholders = [
      'merchant_name_here',
      'customer_or_NA',
      'date_time_here',
      'actual_name',
      'actual_company',
      'actual_number',
      'actual_date',
    ];

    for (final placeholder in placeholders) {
      if (sender.toLowerCase().contains(placeholder.toLowerCase()) ||
          recipient.toLowerCase().contains(placeholder.toLowerCase()) ||
          time.toLowerCase().contains(placeholder.toLowerCase())) {
        print('Rejected response with placeholder text: $placeholder');
        return null; // Reject this response
      }
    }

    // Validate that we have at least some real data
    final amount = _parseAmount(data['amount']);
    if (amount == 0.0 && sender == 'N/A' && time == 'N/A') {
      print('Rejected response with no valid data');
      return null;
    }

    // Ensure all required fields exist
    final normalized = <String, dynamic>{
      'sender': sender,
      'recipient': recipient,
      'amount': amount,
      'time': time,
    };

    print('✓ Extracted data: $normalized');
    return normalized;
  }

  /// Parse amount field to double
  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      // Remove currency symbols, commas, and Vietnamese text like "VNĐ", "đ"
      final cleaned = amount
          .replaceAll(
            RegExp(r'[^\d.]'),
            '',
          ) // Remove non-numeric except decimal
          .replaceAll(RegExp(r'VN[DĐ]|đ|đồng', caseSensitive: false), '') // Remove Vietnamese currency
          .replaceAll(' ', '')
          .trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  /// Enhanced extraction for Vietnamese receipts (fallback when AI fails)
  /// Extracts data directly from OCR text using pattern matching
  /// For Vietnamese receipts: sender = người chuyển/từ, recipient = người nhận/công ty/ngân hàng
  Map<String, dynamic> extractFromVietnameseReceipt(String text) {
    final result = <String, dynamic>{
      'sender': 'N/A',
      'recipient': 'N/A',
      'amount': 0.0,
      'time': 'N/A',
    };

    try {
      // Use parseReceiptText to extract amount reliably
      final parsedData = parseReceiptText(text);
      if (parsedData['total'] != null && parsedData['total'] > 0) {
        result['amount'] = parsedData['total'] as double;
        print('✓ Found amount from parseReceiptText: ${result['amount']}');
      } else {
        // Fallback: Try Vietnamese-specific patterns
        final amountPatterns = [
          RegExp(
            r'(?:Số\s*tiền|Tổng\s*cộng|Thành\s*tiền|Thanh\s*toán|Total|Amount|Due)(?:.|\n){0,30}?(\d{1,3}(?:[,\.]\d{3})+)\s*(?:VNĐ|VND|đ|đồng)?', caseSensitive: false
          ),
          RegExp(
            r'(\d{1,3}(?:[,\.]\d{3})+)\s*(?:VNĐ|VND|đ|đồng)', caseSensitive: false
          ),
          RegExp(
            r'(?:Số tiền|Tổng cộng|Thành tiền|Thanh toán|Total)\s*:?\s*(\d+(?:[,\.]\d+)*)', caseSensitive: false
          ),
        ];

        for (final pattern in amountPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null && match.groupCount >= 1) {
            final amountStr = match.group(1);
            if (amountStr != null && amountStr.isNotEmpty) {
              // Remove commas and parse
              final cleanAmount = amountStr.replaceAll(',', '');
              final amount = double.tryParse(cleanAmount);
              if (amount != null && amount > 0) {
                result['amount'] = amount;
                print('✓ Found amount from Vietnamese pattern: $amount');
                break;
              }
            }
          }
        }
      }

      // Extract sender - person making payment or merchant
      // First try to use the merchant extracted from the top of the receipt
      if (parsedData['merchant'] != null && parsedData['merchant'].toString().isNotEmpty) {
        result['sender'] = parsedData['merchant'];
      }

      final senderPatterns = [
        RegExp(r'(?:Người\s*gửi|Từ|Người\s*chuyển)\s*:?\s*([a-zA-ZÀ-ỹ\s]{3,30})', caseSensitive: false),
        RegExp(r'(AEON|Starbucks|Highlands|Cộng|Phúc Long|KFC|Lotteria|Winmart|Circle\s*K|FamilyMart|Ministop)', caseSensitive: false),
        RegExp(r'GrabPay\s*Wallet', caseSensitive: false), // Fallback for English
      ];

      if (result['sender'] == 'N/A' || result['sender'].toString().length < 3) {
        for (final pattern in senderPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null && match.groupCount >= 1) {
            final group1 = match.group(1);
            final group0 = match.group(0);
            if (group1 != null && group1.isNotEmpty) {
              result['sender'] = group1.trim();
              break;
            } else if (group0 != null && group0.isNotEmpty) {
              result['sender'] = group0.trim();
              break;
            }
          }
        }
      }
      
      // Attempt to enforce sender validation
      if (result['sender'] == null || result['sender'].toString().trim().isEmpty) {
        result['sender'] = 'N/A';
      }

      // Extract recipient
      final recipientPatterns = [
        RegExp(r'(?:Công\s*ty\s*(?:TNHH|CP)?|CTY)\s*([a-zA-ZÀ-ỹ\s&]+)', caseSensitive: false),
        RegExp(r'(?:Ngân\s*hàng|NH)\s*([a-zA-ZÀ-ỹ\s]+)', caseSensitive: false),
        RegExp(r'(?:Tới|Người\s*nhận|Đến)\s*:?\s*([a-zA-ZÀ-ỹ\s]+)', caseSensitive: false),
        RegExp(r'(Vietcombank|Techcombank|MBBank|VietinBank|BIDV|Agribank)', caseSensitive: false),
      ];

      for (final pattern in recipientPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          final group1 = match.group(1);
          final group0 = match.group(0);
          final extracted = group1 ?? group0;
          if (extracted != null && extracted.isNotEmpty) {
            result['recipient'] = extracted.trim().replaceAll(
              RegExp(r'\s+'),
              ' ',
            );
            break;
          }
        }
      }
      
      // Default recipient if it couldn't find one
      if (result['recipient'] == 'N/A' || result['recipient'].toString().trim().isEmpty) {
        result['recipient'] = 'Bản thân (Tôi)';
      }

      // Extract time
      final timePatterns = [
        RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\s*(\d{1,2}:\d{2})'), // Date/time
        RegExp(r'Ngày\s*(\d{1,2})\s*tháng\s*(\d{1,2})\s*năm\s*(\d{4})(?:\s*(\d{1,2}:\d{2}))?', caseSensitive: false), // Vietnamese format
        RegExp(r'(\d{4})-(\d{2})-(\d{2})\s*(\d{2}:\d{2})'), // ISO format
      ];

      for (final pattern in timePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 3) {
          try {
            if (pattern.pattern.contains('Ngày')) {
              final d = match.group(1)!.padLeft(2, '0');
              final m = match.group(2)!.padLeft(2, '0');
              final y = match.group(3)!;
              final t = match.groupCount >= 4 ? (match.group(4) ?? '00:00') : '00:00';
              result['time'] = '$d/$m/$y $t';
              break;
            } else if (match.group(1)!.length == 4) { // ISO (yyyy-mm-dd)
              final y = match.group(1)!;
              final m = match.group(2)!.padLeft(2, '0');
              final d = match.group(3)!.padLeft(2, '0');
              final t = match.group(4)!;
              result['time'] = '$d/$m/$y $t';
              break;
            } else { // dd/mm/yyyy
              final d = match.group(1)!.padLeft(2, '0');
              final m = match.group(2)!.padLeft(2, '0');
              final y = match.group(3)!.length == 2 ? '20${match.group(3)}' : match.group(3)!;
              final t = match.group(4)!;
              result['time'] = '$d/$m/$y $t';
              break;
            }
          } catch (e) {
            result['time'] = match.group(0)?.trim() ?? 'N/A';
            break;
          }
        }
      }

      print('✓ Enhanced extraction result: $result');
    } catch (e, stackTrace) {
      print('Error in enhanced extraction: $e');
      print('Stack trace: $stackTrace');
    }

    return result;
  }
}

// ---------------------------------------
// Background isolate helpers (top-level)
// ---------------------------------------

Future<void> _preprocessImageCompute(Map<String, String> args) async {
  _preprocessImageSync(
    inputPath: args['inputPath']!,
    outputPath: args['outputPath']!,
  );
}

void _preprocessImageSync({
  required String inputPath,
  required String outputPath,
}) {
  // Read and decode (sync IO is fine here; it runs in a background isolate when used with compute()).
  final bytes = File(inputPath).readAsBytesSync();
  final image = img.decodeImage(bytes);

  if (image == null) {
    throw Exception('Failed to decode image');
  }

  print('Original image size: ${image.width}x${image.height}');

  // Convert to grayscale
  final grayscale = img.grayscale(image);

  // Ensure minimum DPI of 300 (approx by scaling width to A4@300DPI)
  const targetWidth = 2480; // ~8.27 inches at 300 DPI (A4 width)

  img.Image processed = grayscale;
  if (grayscale.width < targetWidth) {
    final scaleFactor = targetWidth / grayscale.width;
    final newWidth = (grayscale.width * scaleFactor).round();
    final newHeight = (grayscale.height * scaleFactor).round();

    processed = img.copyResize(
      grayscale,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  // Light preprocessing
  processed = img.contrast(processed, contrast: 110);

  // Write PNG (sync)
  File(outputPath).writeAsBytesSync(img.encodePng(processed));
}

Future<String> _tesseractOcrCompute(Map<String, Object?> args) async {
  final token = args['rootToken'] as RootIsolateToken?;
  if (token == null) {
    throw Exception('RootIsolateToken is null');
  }
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final imagePath = args['imagePath'] as String;
  final language = args['language'] as String;
  final ocrArgs = (args['args'] as Map).cast<String, String>();

  return FlutterTesseractOcr.extractText(
    imagePath,
    language: language,
    args: ocrArgs,
  );
}
