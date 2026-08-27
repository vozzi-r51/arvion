# TFLite Intent Classifier Training Guide

## Overview
This guide explains how to train a TensorFlow Lite text classification model for DukanEdge AI intent detection.

## Prerequisites
- Google Colab account (free)
- TensorFlow 2.x
- Training data: `intent_training.csv` (provided)

## Steps

### Step 1: Open Google Colab
1. Go to https://colab.research.google.com/
2. Create new notebook
3. Copy the code below into cells

### Step 2: Install Dependencies
```python
!pip install tensorflow tensorflow-text tensorflow-hub
```

### Step 3: Load Training Data
```python
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import numpy as np

# Load training data
data = pd.read_csv('intent_training.csv')

# Map intent names to indices
intent_to_idx = {
    'getSales': 0,
    'getLowStock': 1,
    'getReceivables': 2,
    'getExpenses': 3,
    'getProfit': 4,
    'getPurchases': 5,
    'getSupplierCount': 6,
    'getProductCount': 7,
    'createExpense': 8,
}

# Convert intents to indices
data['intent_idx'] = data['intent'].map(intent_to_idx)

print(f"Loaded {len(data)} training examples")
print(f"Intent distribution:\n{data['intent'].value_counts()}")
```

### Step 4: Prepare Text Data
```python
from tensorflow.keras.preprocessing.text import Tokenizer
from tensorflow.keras.preprocessing.sequence import pad_sequences

# Tokenize text
tokenizer = Tokenizer(num_words=1000, lower=True)
tokenizer.fit_on_texts(data['query'].values)

# Convert to sequences
X = tokenizer.texts_to_sequences(data['query'].values)
X = pad_sequences(X, maxlen=20, padding='post')

# Labels
y = data['intent_idx'].values

print(f"Input shape: {X.shape}")
print(f"Output classes: {len(np.unique(y))}")
```

### Step 5: Split Data
```python
from sklearn.model_selection import train_test_split

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"Training set: {X_train.shape[0]}")
print(f"Test set: {X_test.shape[0]}")
```

### Step 6: Build Model
```python
model = keras.Sequential([
    layers.Embedding(1000, 64, input_length=20),
    layers.GlobalAveragePooling1D(),
    layers.Dense(64, activation='relu'),
    layers.Dropout(0.2),
    layers.Dense(32, activation='relu'),
    layers.Dropout(0.2),
    layers.Dense(9, activation='softmax')  # 9 intents
])

model.compile(
    loss='sparse_categorical_crossentropy',
    optimizer='adam',
    metrics=['accuracy']
)

model.summary()
```

### Step 7: Train Model
```python
history = model.fit(
    X_train, y_train,
    epochs=50,
    batch_size=8,
    validation_data=(X_test, y_test),
    verbose=1
)

# Evaluate
test_loss, test_acc = model.evaluate(X_test, y_test)
print(f"Test Accuracy: {test_acc:.4f}")
```

### Step 8: Convert to TFLite
```python
# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
]

tflite_model = converter.convert()

# Save model
with open('intent_classifier.tflite', 'wb') as f:
    f.write(tflite_model)

print("Model saved as intent_classifier.tflite")
```

### Step 9: Download Model
1. In Colab left sidebar, click "Files"
2. Right-click `intent_classifier.tflite`
3. Click "Download"
4. Save to: `dukanedge/assets/models/intent_classifier.tflite`

### Step 10: Save Tokenizer Info
```python
import json

# Save tokenizer config for app
tokenizer_config = {
    'num_words': 1000,
    'maxlen': 20,
    'word_index': tokenizer.word_index  # vocabulary mapping
}

with open('tokenizer_config.json', 'w') as f:
    json.dump(tokenizer_config, f)

print("Tokenizer config saved")
```

## Expected Output
```
Test Accuracy: 0.8500  (target: >85%)
Model size: 45KB (after quantization, very small!)
```

## Troubleshooting

**Low Accuracy (<85%)?**
- Add more training examples
- Increase model capacity (more layers)
- Train for more epochs

**Model Too Large?**
- Use full quantization: `converter.optimizations = [tf.lite.Optimize.DEFAULT]`
- Reduce embedding dimension (from 64 to 32)

**Out of Memory in Colab?**
- Reduce batch size (from 8 to 4)
- Reduce training data size

## Next Steps (In Flutter App)
1. Copy `intent_classifier.tflite` to `assets/models/`
2. Create `lib/core/services/tflite_intent_classifier.dart`
3. Update `lib/features/ai/ai_engine.dart`
4. Test on real device

## Files Generated
- `intent_classifier.tflite` (45-50KB) → copy to Flutter app
- `tokenizer_config.json` (reference for app tokenization)
- Training history plot (for documentation)
