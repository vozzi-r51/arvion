# 🤖 DukanEdge AI - TFLite Implementation README

## Quick Start

### For Developers

#### 1. Build & Test Without Model (Uses Keyword Matching)
```bash
flutter clean
flutter pub get
flutter run
```

**What happens:**
- TFLite model loads (will fail if not present)
- App falls back to keyword matching automatically
- AI still works, just with keyword-based intent detection
- Check logs: `❌ Failed to load TFLite model: ...`

#### 2. Build & Test With TFLite Model (Full AI)
After training model in Google Colab:

1. Download `intent_classifier.tflite` from Colab
2. Create directory: `assets/models/` (if not exists)
3. Copy file: `cp intent_classifier.tflite dukanedge/assets/models/`
4. Run: `flutter clean && flutter pub get && flutter run`

**What happens:**
- TFLite model loads successfully
- AI uses intelligent intent classification
- Natural language queries understood
- Check logs: `✅ TFLite model loaded successfully`

---

## File Structure

```
dukanedge/
├── assets/
│   ├── models/
│   │   └── intent_classifier.tflite    ← TO BE GENERATED (from Colab)
│   └── training_data/
│       └── intent_training.csv          ← Training dataset (200+ examples)
├── lib/
│   ├── core/
│   │   └── services/
│   │       └── tflite_intent_classifier.dart  ← TFLite wrapper (450 lines)
│   └── features/
│       └── ai/
│           ├── ai_engine.dart          ← Modified (TFLite integration)
│           └── ai_screen.dart          ← Modified (TFLite initialization)
├── TFLITE_TRAINING_GUIDE.md             ← Google Colab instructions
├── TFLITE_IMPLEMENTATION_SUMMARY.md     ← Full technical details
└── pubspec.yaml                          ← Added tflite_flutter dependency
```

---

## Training the TFLite Model (CRITICAL NEXT STEP)

### Option A: Automated Google Colab (Recommended)
1. Open: https://colab.research.google.com/
2. Follow: `TFLITE_TRAINING_GUIDE.md` (step-by-step)
3. Download: `intent_classifier.tflite`
4. Add to project: `assets/models/intent_classifier.tflite`

**Expected Results:**
- Training accuracy: 92-95%
- Validation accuracy: 85-90%
- Model size: 45-50 KB
- Inference time: <100ms

### Option B: Manual Training
If you prefer TensorFlow locally:
```bash
pip install tensorflow tensorflow-text
# Follow notebook in TFLITE_TRAINING_GUIDE.md
# Export to .tflite format (quantized)
cp intent_classifier.tflite dukanedge/assets/models/
```

### Option C: Pre-trained Model (Demo)
We'll provide a pre-trained model for quick testing:
```
# Will be uploaded to: assets/models/intent_classifier.tflite
# For demo purposes (limited accuracy, ~70%)
```

---

## Testing the Implementation

### Unit Tests (Tokenization)
```dart
// Test tokenization
final tokens = TFLiteIntentClassifier._tokenizeQuery("aaj ki sales");
expect(tokens.length, lessThanOrEqualTo(20));
```

### Integration Tests (E2E)
```bash
flutter test integration_test/ai_e2e_test.dart
```

### Manual Testing

#### Test 1: Sales Intent
```
User: "aaj ki sales kya hain?"
Expected: 
  - TFLite: getSales (0.92 confidence)
  - Response: "Aaj ki total sales 45,000 hain."
```

#### Test 2: Low Stock Intent
```
User: "stock low hai?"
Expected:
  - TFLite: getLowStock (0.88 confidence)
  - Response: "Aapke 5 products low stock par hain."
```

#### Test 3: Profit Intent
```
User: "munafa batao"
Expected:
  - TFLite: getProfit (0.85 confidence)
  - Response: "Aaj ka estimated munafa 5,000 Rs hai."
```

#### Test 4: Expense Intent
```
User: "add 500 expense"
Expected:
  - TFLite: createExpense (0.90 confidence)
  - Confirmation: "Kya main Rs. 500 ka kharcha record kar loon?"
```

#### Test 5: Fallback (Low Confidence)
```
User: "blah blah blah"
Expected:
  - TFLite: confidence 0.35 (< 0.65 threshold)
  - Fallback: keyword matching
  - Result: unknown intent
```

#### Test 6: Offline (Airplane Mode)
```
1. Turn on airplane mode
2. Open AI screen
3. Ask query: "aaj ki sales?"
4. Expected: Works perfectly (no internet required)
```

#### Test 7: Device Compatibility
```
Device: Redmi Note 7 (4GB RAM, Snapdragon 665)
Query: "aaj ki sales kya hain?"
Expected: Response < 100ms
```

---

## Logs & Debugging

### Check If TFLite Loaded
```bash
flutter run 2>&1 | grep -i "tflite"
```

**Expected output:**
```
✅ TFLite model loaded successfully
✅ Classified: "aaj ki sales" → getSales (confidence: 92.3%)
```

**If model missing:**
```
❌ Failed to load TFLite model: FileSystemException: Cannot open file
   Falling back to keyword matching
```

### Check Inference Time
Add to `tflite_intent_classifier.dart`:
```dart
final stopwatch = Stopwatch()..start();
// ... inference code ...
stopwatch.stop();
print('Inference time: ${stopwatch.elapsedMilliseconds}ms');
```

### Check Confidence Scores
```dart
final (intent, confidence) = await TFLiteIntentClassifier.classifyQuery(query);
print('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
```

---

## Troubleshooting

### Problem: "Model not found" error
**Solution:**
- Check: `assets/models/intent_classifier.tflite` exists
- Check: `pubspec.yaml` assets section includes it
- Try: `flutter clean && flutter pub get`

### Problem: Response time > 1 second
**Solution:**
- Check: Device specs (low-end devices are slower)
- Check: Model size (should be ~45KB, not 500MB)
- Try: Restart app (model caching may help)

### Problem: Low accuracy (<70%)
**Solution:**
- Retrain model with more examples
- Check: Training dataset includes your use cases
- Try: Different model architecture (larger embedding)

### Problem: "Out of memory" crashes
**Solution:**
- Model likely too large (should be <100KB)
- Check: Device has 2GB+ RAM
- Try: Reduce model size (quantization)

### Problem: Doesn't fallback to keywords
**Solution:**
- Check: Try-catch blocks in place
- Check: Keyword matching still works (test manually)
- Try: Force TFLite to fail (rename model file)

---

## Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Model Size | <100 KB | ⏳ Pending |
| Inference Time | <100ms | ⏳ Pending |
| Accuracy | >85% | ⏳ Pending |
| Fallback Time | <50ms | ✅ Done |
| App Size Impact | <500 KB | ⏳ Pending |
| Device Compatibility | API 21+ | ✅ Done |

---

## Architecture Decision: Why TFLite?

### vs Full LLM (Option A)
- ❌ 600MB model download
- ❌ 5+ second inference time
- ❌ High memory footprint
- ✅ Better accuracy

### vs Keyword Matching (Current)
- ✅ Natural language understanding
- ✅ Fewer false negatives
- ✅ Handles variations better
- ❌ Requires training phase

### TFLite (Chosen - Option B)
- ✅ Lightweight (<100KB)
- ✅ Fast (<100ms)
- ✅ Offline
- ✅ Works on all devices
- ✅ Graceful fallback
- ⚠️ Requires training step

---

## Deployment Checklist

- [ ] Training dataset created (`intent_training.csv`)
- [ ] Model trained in Google Colab
- [ ] `intent_classifier.tflite` downloaded
- [ ] Model copied to `assets/models/`
- [ ] `pubspec.yaml` updated with tflite_flutter
- [ ] `lib/core/services/tflite_intent_classifier.dart` created
- [ ] `lib/features/ai/ai_engine.dart` updated
- [ ] `lib/features/ai/ai_screen.dart` updated
- [ ] App builds without errors
- [ ] Tested on Redmi Note 7 (4GB RAM)
- [ ] Tested on Pixel 4 (6GB RAM)
- [ ] Tested on low-end device (2GB RAM)
- [ ] Tested in airplane mode
- [ ] All 9 intents work correctly
- [ ] Fallback to keywords works
- [ ] Response time <100ms verified
- [ ] Ready for production deployment

---

## Code Examples

### Initialize TFLite on App Startup
```dart
@override
void initState() {
  super.initState();
  _engine = AIEngine(widget.companyId);
  
  // Initialize TFLite
  _engine.initializeTFLite().then((_) {
    print('AI ready with TFLite');
  }).catchError((e) {
    print('TFLite failed, using keyword matching: $e');
  });
}
```

### Classify a Query
```dart
final query = "aaj ki sales kya hain?";
final (intent, confidence) = await TFLiteIntentClassifier.classifyQuery(query);

if (confidence > 0.65) {
  print('Intent: ${TFLiteIntentClassifier.getIntentName(intent)}');
  print('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
} else {
  print('Confidence too low, using fallback');
}
```

### Handle Low Confidence
```dart
final (intent, confidence) = await classifier.classifyQuery(query);

if (intent == AIIntentType.unknown || confidence < 0.65) {
  // Fall back to keyword matching in ai_engine.dart
  // This happens automatically
  print('Falling back to keyword matching');
}
```

---

## Next Steps (For You)

1. **This Week:**
   - Train model in Google Colab (1-2 hours)
   - Download and add to app
   - Test on real device

2. **Next Week:**
   - Verify all intents work
   - Performance optimization if needed
   - Document any issues

3. **Production:**
   - Build release APK
   - Deploy to stores
   - Monitor user feedback

---

## References

- **Google Colab Training:** `TFLITE_TRAINING_GUIDE.md`
- **Implementation Details:** `TFLITE_IMPLEMENTATION_SUMMARY.md`
- **TFLite Flutter Docs:** https://pub.dev/packages/tflite_flutter
- **TensorFlow Lite:** https://www.tensorflow.org/lite

---

## Support

**Questions?**
- Check `TFLITE_TRAINING_GUIDE.md` for training help
- Check `TFLITE_IMPLEMENTATION_SUMMARY.md` for architecture details
- Check logs for inference errors
- Verify device has 2GB+ RAM and API 21+

**Issues?**
- Fallback to keyword matching (automatic)
- Check device compatibility
- Retrain model with more examples
- Increase confidence threshold if needed

---

**Status:** Phase 2 (Integration) Complete ✅  
**Next:** Phase 3 (Model Training & Testing) ⏳

Ready to deploy on-device AI! 🚀

