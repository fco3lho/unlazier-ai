# Global Agent Rules

This document defines the mandatory standards for all code generation, refactoring, and documentation tasks.

## 1. Language and Naming Conventions
* **English Only:** All code elements, including variables, functions, classes, and constants, must be named in English.
* **Documentation:** All documentation, docstrings, and comments must be written in English.
    * **Style:** Maintain a professional and sober tone.
    * **Restrictions:** Do not use **CAPSLOCK** for emphasis (except for constants/env vars as per language standards).>

## 2. Architecture and Paradigm
* **Clean Code:** Follow Clean Code principles strictly. Prioritize code readability, maintainability, and efficiency. >
* **Functional Programming:** Follow functional programming principles whenever applicable:
    * Favor immutability over mutation.
    * Use pure functions to minimize side effects.
    * Utilize higher-order functions (map, filter, reduce) instead of imperative loops where possible.
    * Prioritize declarative code over imperative logic.

## 3. Formatting
* **Indentation:** Always use exactly **4 spaces** for indentation.
* **Consistency:** Ensure consistent spacing around operators and after commas to enhance legibility.

## 4. Documentation Standards
* Provide clear and concise explanations.
* Focus on the "why" and "how" of complex logic, avoiding obvious comments for self-explanatory code.
* Always explain about execute the code

## 5. Code
* Always import libraries and packages at the top of the file, along with other imports.
* Always prefer using Snake Case if the code doesn't already have a standard.
