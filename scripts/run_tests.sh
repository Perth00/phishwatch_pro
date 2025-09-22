#!/bin/bash

echo "Starting PhishWatch Pro Automated Testing..."
echo

# Get dependencies
echo "Installing dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "Failed to get dependencies"
    exit 1
fi

echo
echo "Running automated test suite..."
dart run test_runner.dart

echo
echo "Test execution completed!"

