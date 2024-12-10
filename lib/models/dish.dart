class Dish {
  final String name;
  final String note;
  final List<Ingredient> ingredients;
  final List<Spice> spices;
  final List<Zone> steps;

  Dish({
    required this.name,
    required this.note,
    required this.ingredients,
    required this.spices,
    required this.steps,
  });
}

class Ingredient {
  final String name;
  final String count;
  final String unit;
  final bool optional;

  Ingredient({
    required this.name,
    required this.count,
    required this.unit,
    this.optional = false,
  });
}

class Spice {
  final String name;
  final String? count;
  final String? unit;
  final String? note;
  final bool optional;

  Spice({
    required this.name,
    this.count,
    this.unit,
    this.note,
    this.optional = false,
  });
}

class Zone {
  final String id;
  final String text;
  final List<RecipeStep> steps;

  Zone({
    required this.id,
    required this.text,
    required this.steps,
  });
}

class RecipeStep {
  final String id;
  final String text;

  RecipeStep({
    required this.id,
    required this.text,
  });
} 