# Cookrange

Cookrange is an innovative mobile application powered by artificial intelligence that creates personalized meal plans. It offers practical, flexible, and smart solutions for individuals who want to eat healthy and regularly in the modern pace of life. Cookrange is not just a meal planner, but also a personal nutrition assistant that understands you, adapts to your habits, and facilitates your transition to healthy living.

## Features

- **Personalized Meal Plans:** Daily/weekly meal suggestions based on your goals (muscle gain, fat loss, general fitness, etc.) and preferences.
- **AI-Powered Assistant:** Guidance on meal selection and achieving nutrition goals.
- **Calorie and Nutrient Tracking:** Detailed calorie and macro/micro nutrient analysis for each meal.
- **User Profile:** Plans fully compatible with personal information such as gender, age, height, weight, activity level.
- **Dietary Restrictions and Preferences:** Vegetarian, vegan, allergen filters, and more.
- **Modern and User-Friendly Interface:** Sleek and intuitive design fully compatible with mobile devices.
- **Multi-Language Support:** English and Turkish interface.

## Screenshots

| Onboarding | Home Screen | Meal Details |
|------------|-------------|--------------|
|will be added|will be added|will be added|

<!-- | ![Onboarding](assets/images/onboarding/onboarding-1.png) | ![Logo](cookrange-logo.png) | ![Onboarding](assets/images/onboarding/onboarding-2-1.png) | -->

## Installation

### Requirements

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>=3.0.0 <4.0.0)
- [Dart](https://dart.dev/get-dart)
- Android Studio or Xcode (for mobile development)
- Firebase account (for analytics and crash reporting)

### Steps

1. **Clone the Repository:**
    ```bash
    git clone https://github.com/burcok/cookrange.git
    cd cookrange
    ```

2. **Clean Flutter Cache:**
    ```bash
    flutter clean
    ```

3. **Install Dependencies:**
    ```bash
    flutter pub upgrade --major-versions
    flutter pub get
    ```

4. **Set Up Environment Files:**
    - Add `.env` file to the root directory and enter required keys.

5. **Launch the Application:**
    ```bash
    flutter run
    ```

## Usage

1. **Profile Creation and Onboarding:**
   - Follow the onboarding steps when first launching the app to create your personal profile.
   - Specify your goals (e.g., muscle gain, fat loss, healthy living), dietary preferences, and any allergies.
   - Enter your gender, age, height, weight, activity level for a personalized nutrition plan.

2. **Account Registration and Premium Membership:**
   - Complete the registration process to create your account.
   - If you register through a partner gym, enjoy 2 weeks of free premium membership. Individual users receive 1 week of free premium access.
   - Access advanced features and personalized content with premium membership.

3. **Social and Community Features:**
   - Connect and exchange ideas with other users in your gym's exclusive chat rooms.
   - Increase motivation and share experiences with community support.

4. **AI-Powered Meal Lists:**
   - View personalized meal plans created by AI from the main menu.
   - Review daily or weekly suggested meals and portions.

5. **Meal and Nutrition Information:**
   - View calorie and macro/micro nutrient values on each meal's detail page.
   - Easily track your nutrition according to your dietary goals.

6. **Voice Assistant Interaction:**
   - Use the in-app voice assistant to get information about your program, update your meal list, or request new suggestions.
   - Experience hands-free usage for practical interaction.

7. **Shopping List and Ingredient Tracking:**
   - Easily view ingredients from your meal list.
   - Create shopping lists with one click and make your grocery shopping more efficient.

8. **Profile and Goal Updates:**
   - Update your profile information, goals, or dietary preferences at any time.
   - The app automatically updates your meal plan according to your new information.

---

Follow these steps to maximize your benefits from Cookrange's features and easily manage your healthy and balanced nutrition journey.

## Commands

| Command             | Description                                |
|--------------------|-------------------------------------------|
| `flutter run`      | Launches the application                   |
| `flutter build apk`| Creates production APK for Android         |
| `flutter build ios`| Creates production build for iOS           |
| `flutter test`     | Runs tests                                |

## Tests

- Basic widget tests are available in the `test/widget_test.dart` file.
- You can enhance the application's reliability by adding your own tests.

## Technologies Used

- **Flutter**: Modern, cross-platform mobile application development.
- **Firebase**: Analytics, crash reporting, and more.
- **Provider**: State management.
- **Hive**: Local data storage.
- **Webview**: Figma prototype integration.
- **Others:** shared_preferences, connectivity_plus, flutter_screenutil, etc.

## Contributing

We welcome your contributions! Please follow these steps:

1. Fork the repository (https://github.com/burcok/cookrange/fork)
2. Create a new branch (`git checkout -b feature/newFeature`)
3. Make your changes and commit (`git commit -am 'New feature description'`)
4. Push to your branch (`git push origin feature/newFeature`)
5. Open a Pull Request

## License

This project is proprietary and confidential. All rights reserved. Any use, copying, modification, or distribution of this software requires written permission from Burak Dereli. For detailed terms and conditions, please refer to the [LICENSE](LICENSE) file.

## Contact

For any questions or suggestions, please contact us at [email](mailto:burakdereli05@gmail.com).

---

> **Note:** Please refer to the `.env`, `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist` files and related documentation for developer documentation, API keys, and special settings.
