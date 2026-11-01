
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/user.dart';
import '../../models/meal_plan.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/pantry_service.dart';
import '../../services/ingredient_service.dart';
import '../groceries/grocery_list_screen.dart';
import '../meal_plans/weekly_meal_planner_screen.dart';
import '../recipes/recipe_catalog_screen.dart';
import '../recipes/my_recipes_screen.dart';
import '../recipes/saved_recipes_screen.dart';
import '../pantry/my_pantry_screen.dart';
import '../pantry/cook_with_what_i_have_screen.dart';
import '../../services/pantry_matching_service.dart';
import '../../services/preferences_service.dart';
import '../preferences/food_preferences_screen.dart';
import '../recipes/recommendations_screen.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/kitchen_destinations.dart';
import '../../services/recipe_service.dart';
import '../../services/meal_plan_service.dart';
import '../../services/grocery_list_service.dart';
import 'home_dashboard.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthService? authService;
  final ProfileService? profileService;
  final PantryService? pantryService;
  final IngredientService? ingredientService;
  final PantryMatchingService? matchingService;
  final PreferencesService? preferencesService;
  final RecommendationService? recommendationService;
  final RecipeService? recipeService;
  final MealPlanService? mealPlanService;
  final GroceryListService? groceryListService;
  const HomeScreen({
    super.key,
    this.authService,
    this.profileService,
    this.pantryService,
    this.ingredientService,
    this.matchingService,
    this.preferencesService,
    this.recommendationService,
    this.recipeService,
    this.mealPlanService,
    this.groceryListService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _authService;
  late final RecommendationService _recommendations =
      widget.recommendationService ?? RecommendationService();
  late final RecipeService _recipes = widget.recipeService ?? RecipeService();
  late final MealPlanService _plans =
      widget.mealPlanService ?? MealPlanService();
  late final GroceryListService _groceries =
      widget.groceryListService ?? GroceryListService();
  late final PantryMatchingService _matches =
      widget.matchingService ?? PantryMatchingService();
  int _refreshToken = 0;
  DateTime _previewDate = mealPlanDay(DateTime.now());

  bool? _wasActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = KitchenDestinations.maybeOf(context)?.selectedIndex == 0;
    if (active && _wasActive == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadUserProfile();
      });
    }
    _wasActive = active;
  }

  @override
  void dispose() {
    super.dispose();
  }

  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _refreshToken++;
    });

    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await _handleLogout();
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your profile. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (route) => false,
    );
  }

  Future<void> _openProfile() async {
    final user = _currentUser;
    if (user == null) return;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: user,
          profileService: widget.profileService ?? ProfileService(),
          onPreferences: () => open(
            FoodPreferencesScreen(
              preferencesService: widget.preferencesService,
              ingredientService: widget.ingredientService,
            ),
          ),
          onSaved: () => open(
            SavedRecipesScreen(
              recipeService: _recipes,
              authService: _authService,
              ingredientService: widget.ingredientService,
            ),
          ),
          onRecipes: () => open(
            MyRecipesScreen(
              recipeService: _recipes,
              authService: _authService,
              ingredientService: widget.ingredientService,
            ),
          ),
          onLogout: _showLogoutDialog,
        ),
      ),
    );
    if (mounted) await _loadUserProfile();
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 18) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F9F6),
        leading: Tooltip(
          message: 'Profile & Settings',
          child: InkWell(
            onTap: _currentUser == null ? null : _openProfile,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Builder(
                builder: (context) {
                  return CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      _currentUser?.name.trim().isNotEmpty == true
                          ? _currentUser!.name
                                .trim()
                                .characters
                                .first
                                .toUpperCase()
                          : 'ا',
                      style: const TextStyle(color: AppColors.primaryDark),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        title: const Text('Akletna اكلتنا'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: AppColors.primary),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadUserProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final firstName = _currentUser?.name.split(' ').first ?? 'Chef';
    Future<void> open(Widget screen) async {
      final destinations = KitchenDestinations.maybeOf(context);
      final index = switch (screen) {
        RecipeCatalogScreen() => 1,
        WeeklyMealPlannerScreen() => 2,
        GroceryListScreen() => 3,
        MyPantryScreen() => 4,
        _ => null,
      };
      if (destinations != null && index != null) {
        if (screen is WeeklyMealPlannerScreen &&
            screen.initialDate != null &&
            destinations.selectPlanner != null) {
          destinations.selectPlanner!(screen.initialDate!);
        } else {
          destinations.select(index);
        }
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
        if (mounted) setState(() => _refreshToken++);
      }
    }

    Widget section(String title) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 24, bottom: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
    Widget link(
      IconData icon,
      String title,
      String subtitle,
      Widget screen, {
      bool prominent = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _buildFeatureCard(
        icon: icon,
        title: title,
        subtitle: subtitle,
        color: prominent ? AppColors.primary : AppColors.secondary,
        prominent: prominent,
        onTap: () => open(screen),
      ),
    );
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadUserProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getTimeGreeting()}, $firstName',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'What are we cooking today?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              HomeDashboard(
                selectedDate: _previewDate,
                onDateSelected: (date) => _previewDate = date,
                refreshToken: _refreshToken,
                recommendationService: _recommendations,
                openPreferences: () => open(
                  FoodPreferencesScreen(
                    preferencesService: widget.preferencesService,
                    ingredientService: widget.ingredientService,
                  ),
                ),
                recipeService: _recipes,
                mealPlanService: _plans,
                groceryService: _groceries,
                matchingService: _matches,
                authService: _authService,
                openPlanner: (date) => open(
                  WeeklyMealPlannerScreen(
                    initialDate: date,
                    mealPlanService: _plans,
                    recipeService: _recipes,
                  ),
                ),
                openGroceries: () =>
                    open(GroceryListScreen(groceryListService: _groceries)),
                openDiscover: () => open(
                  RecommendationsScreen(
                    homeSelection: true,
                    recommendationService: _recommendations,
                    authService: _authService,
                    recipeService: _recipes,
                    pantryService: widget.pantryService,
                    ingredientService: widget.ingredientService,
                    preferencesService: widget.preferencesService,
                  ),
                ),
                openPantryMatches: () => open(
                  CookWithWhatIHaveScreen(
                    matchingService:
                        widget.matchingService ??
                        PantryMatchingService(minimumHalf: true),
                    pantryService: widget.pantryService,
                    ingredientService: widget.ingredientService,
                    authService: _authService,
                  ),
                ),
              ),
              section('My Kitchen'),
              link(
                Icons.tune,
                'Food Preferences',
                'Dietary preferences, allergies and goals',
                FoodPreferencesScreen(
                  preferencesService: widget.preferencesService,
                  ingredientService: widget.ingredientService,
                ),
              ),
              link(
                Icons.bookmark_border,
                'Saved Recipes',
                'Find your favourites again',
                SavedRecipesScreen(
                  recipeService: _recipes,
                  authService: _authService,
                  ingredientService: widget.ingredientService,
                ),
              ),
              link(
                Icons.restaurant_menu,
                'My Recipes',
                'Create and share your own dishes',
                MyRecipesScreen(
                  recipeService: _recipes,
                  authService: _authService,
                  ingredientService: widget.ingredientService,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'صحتين وهنا · Made for your kitchen',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool prominent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: prominent ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out of Akletna?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(80, 48),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
