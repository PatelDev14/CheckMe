import SwiftUI

// MARK: - Category

enum IngredientCategory: String, CaseIterable, Identifiable {
    case preservatives       = "Preservatives"
    case artificialAdditives = "Additives & Colors"
    case sugars              = "Sugars & Sweeteners"
    case oilsFats            = "Oils & Fats"
    case emulsifiers         = "Emulsifiers & Thickeners"
    case vitamins            = "Vitamins & Minerals"
    case proteins            = "Proteins"
    case grainsStarches      = "Grains & Starches"
    case naturalFlavors      = "Natural Flavors"
    case other               = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .preservatives:       return "shield.fill"
        case .artificialAdditives: return "eyedropper.full"
        case .sugars:              return "cube.fill"
        case .oilsFats:            return "drop.fill"
        case .emulsifiers:         return "circle.grid.2x2.fill"
        case .vitamins:            return "capsule.fill"
        case .proteins:            return "bolt.fill"
        case .grainsStarches:      return "circle.hexagonpath.fill"
        case .naturalFlavors:      return "leaf.fill"
        case .other:               return "questionmark.circle.fill"
        }
    }

    var signalColor: Color {
        switch self {
        case .preservatives, .artificialAdditives: return Color(red: 0.95, green: 0.25, blue: 0.25)
        case .sugars:                              return Color(red: 0.95, green: 0.55, blue: 0.10)
        case .oilsFats:                            return Color(red: 0.95, green: 0.80, blue: 0.15)
        case .emulsifiers:                         return Color(red: 0.90, green: 0.75, blue: 0.20)
        case .vitamins:                            return Color(red: 0.20, green: 0.80, blue: 0.45)
        case .proteins:                            return Color(red: 0.55, green: 0.45, blue: 0.95)
        case .grainsStarches:                      return Color(red: 0.80, green: 0.60, blue: 0.40)
        case .naturalFlavors:                      return Color(red: 0.30, green: 0.80, blue: 0.55)
        case .other:                               return Color(white: 0.50)
        }
    }

    var signalBadge: String {
        switch self {
        case .preservatives, .artificialAdditives: return "Watch"
        case .sugars, .oilsFats:                   return "Moderate"
        case .vitamins:                            return "Good"
        default:                                   return "Neutral"
        }
    }
}

// MARK: - Classified Group

struct IngredientGroup: Identifiable {
    let category: IngredientCategory
    let items: [String]
    var id: String { category.id }
}

// MARK: - Classifier

enum IngredientClassifier {

    // Returns the best-matching category for a single ingredient name.
    // Priority order matters: preservatives before sugars catches "sodium benzoate"
    // before the sugar matcher could grab it on a word-overlap.
    static func classify(_ ingredient: String) -> IngredientCategory {
        let s = ingredient.lowercased()
        if matchesPreservatives(s)       { return .preservatives }
        if matchesArtificialAdditives(s) { return .artificialAdditives }
        if matchesSugars(s)              { return .sugars }
        if matchesOilsFats(s)            { return .oilsFats }
        if matchesEmulsifiers(s)         { return .emulsifiers }
        if matchesVitamins(s)            { return .vitamins }
        if matchesProteins(s)            { return .proteins }
        if matchesGrainsStarches(s)      { return .grainsStarches }
        if matchesNaturalFlavors(s)      { return .naturalFlavors }
        return .other
    }

    /// Groups an ingredient list into sorted category buckets.
    /// Most-concerning categories appear first so users see warnings immediately.
    static func categorize(_ ingredients: [String]) -> [IngredientGroup] {
        var buckets: [IngredientCategory: [String]] = [:]
        for ingredient in ingredients {
            let cat = classify(ingredient)
            buckets[cat, default: []].append(ingredient)
        }
        let displayOrder: [IngredientCategory] = [
            .preservatives, .artificialAdditives, .sugars, .oilsFats,
            .emulsifiers, .naturalFlavors, .proteins, .vitamins, .grainsStarches, .other
        ]
        return displayOrder.compactMap { cat in
            guard let items = buckets[cat], !items.isEmpty else { return nil }
            return IngredientGroup(category: cat, items: items)
        }
    }

    // MARK: - Matchers

    private static func matchesPreservatives(_ s: String) -> Bool {
        containsAny(s, [
            "bha", "bht", "tbhq",
            "sodium nitrate", "sodium nitrite", "potassium nitrate", "potassium nitrite",
            "potassium sorbate", "sodium benzoate", "calcium propionate", "sodium propionate",
            "propionic acid", "benzoic acid", "sorbic acid",
            "sulfite", "sulphite", "sulfur dioxide",
            "sodium metabisulfite", "potassium metabisulfite",
            "edta", "calcium disodium", "disodium edta",
            "nisin", "natamycin", "sodium diacetate",
            "ascorbyl palmitate", "erythorbic acid", "sodium erythorbate",
            "tocopherol" // vitamin E as preservative
        ])
    }

    private static func matchesArtificialAdditives(_ s: String) -> Bool {
        containsAny(s, [
            "fd&c", "red 40", "red no.", "yellow 5", "yellow 6", "yellow no.",
            "blue 1", "blue 2", "blue no.", "green 3",
            "titanium dioxide", "caramel color", "caramel colour",
            "artificial color", "artificial colour",
            "artificial flavor", "artificial flavour",
            "monosodium glutamate", "msg",
            "disodium inosinate", "disodium guanylate",
            "polysorbate", "sodium stearoyl lactylate", "ssl",
            "propylene glycol", "acetylated",
            "methylcellulose", "carboxymethylcellulose", "cmc",
            "sodium carboxymethyl"
        ])
    }

    private static func matchesSugars(_ s: String) -> Bool {
        containsAny(s, [
            "sugar", "syrup", "fructose", "glucose", "sucrose", "dextrose",
            "maltose", "lactose", "trehalose",
            "corn syrup", "high fructose", "hfcs",
            "molasses", "honey", "maple", "agave", "stevia",
            "erythritol", "sorbitol", "xylitol", "mannitol", "maltitol",
            "aspartame", "sucralose", "saccharin", "acesulfame",
            "neotame", "advantame", "monk fruit", "luo han guo",
            "turbinado", "muscovado", "coconut sugar", "date sugar",
            "invert sugar", "confectioner", "cane juice",
            "evaporated cane", "beet sugar", "rice syrup",
            "malt syrup", "caramel", "fruit concentrate",
            "juice concentrate", "fruit juice concentrate"
        ])
    }

    private static func matchesOilsFats(_ s: String) -> Bool {
        containsAny(s, [
            "palm oil", "palm kernel", "vegetable oil", "canola oil",
            "soybean oil", "sunflower oil", "safflower oil", "corn oil",
            "olive oil", "coconut oil", "avocado oil", "peanut oil",
            "sesame oil", "flaxseed oil", "grapeseed oil", "cottonseed oil",
            "fish oil", "krill oil", "algal oil",
            "butter", "cream", "lard", "tallow", "suet", "ghee",
            "shortening", "margarine", "cocoa butter", "shea butter",
            "hydrogenated", "partially hydrogenated", "interesterified",
            "fatty acid", "mono- and diglycerides of fatty"
        ])
    }

    private static func matchesEmulsifiers(_ s: String) -> Bool {
        containsAny(s, [
            "lecithin", "guar gum", "xanthan gum", "locust bean gum",
            "carob bean gum", "gum arabic", "gum acacia", "gellan gum",
            "tara gum", "cassia gum", "carrageenan", "agar", "pectin",
            "modified starch", "modified corn starch", "modified food starch",
            "modified tapioca starch", "cellulose gum",
            "microcrystalline cellulose", "hydroxypropyl",
            "mono and diglycerides", "mono- and diglycerides",
            "diacetyl tartaric", "datem", "stearoyl",
            "maltodextrin", "dextrin",
            "corn starch", "tapioca starch", "potato starch",
            "rice starch", "wheat starch", "arrowroot starch"
        ])
    }

    private static func matchesVitamins(_ s: String) -> Bool {
        containsAny(s, [
            "vitamin a", "vitamin b", "vitamin c", "vitamin d", "vitamin e", "vitamin k",
            "niacinamide", "niacin", "thiamin", "thiamine", "riboflavin",
            "pyridoxine", "cobalamin", "folic acid", "folate", "folacin",
            "biotin", "pantothenic acid", "ascorbic acid",
            "retinol", "retinyl", "cholecalciferol", "ergocalciferol",
            "phylloquinone", "menaquinone",
            "ferrous sulfate", "ferrous gluconate", "ferric",
            "zinc oxide", "zinc sulfate", "zinc gluconate",
            "calcium carbonate", "calcium phosphate", "calcium lactate",
            "magnesium oxide", "magnesium sulfate",
            "potassium chloride", "potassium iodide",
            "selenium", "chromium picolinate", "manganese sulfate",
            "copper gluconate", "sodium fluoride"
        ])
    }

    private static func matchesProteins(_ s: String) -> Bool {
        containsAny(s, [
            "whey protein", "whey concentrate", "whey isolate",
            "casein", "caseinate", "sodium caseinate", "calcium caseinate",
            "soy protein", "soy isolate", "soy concentrate",
            "pea protein", "rice protein", "hemp protein",
            "albumin", "egg white", "egg yolk", "egg protein",
            "gluten", "vital wheat gluten",
            "gelatin", "collagen", "collagen peptide", "hydrolyzed collagen",
            "hydrolyzed soy protein", "hydrolyzed wheat protein",
            "hydrolyzed vegetable protein", "hvp",
            "yeast extract", "autolyzed yeast", "brewer's yeast",
            "nutritional yeast", "malt extract"
        ])
    }

    private static func matchesGrainsStarches(_ s: String) -> Bool {
        containsAny(s, [
            "wheat flour", "whole wheat", "enriched flour", "bleached flour",
            "all-purpose flour", "bread flour", "semolina", "durum wheat",
            "spelt", "kamut", "emmer", "einkorn",
            "oat flour", "oatmeal", "rolled oats", "oat bran", "oat fiber",
            "barley flour", "barley malt",
            "rye flour", "rye bran",
            "corn flour", "cornmeal", "masa", "grits",
            "rice flour", "white rice", "brown rice", "rice bran",
            "millet", "sorghum flour", "amaranth flour", "quinoa flour",
            "buckwheat", "teff", "triticale",
            "bran", "wheat germ", "wheat bran",
            "whole grain", "multigrain",
            "bread crumb", "breadcrumb", "panko"
        ])
    }

    private static func matchesNaturalFlavors(_ s: String) -> Bool {
        containsAny(s, [
            "natural flavor", "natural flavour", "natural flavoring",
            "natural flavouring", "nature identical",
            "vanilla extract", "vanilla bean", "vanilla powder",
            "spices", "spice blend", "seasoning",
            "dried herb", "herb extract",
            "fruit extract", "vegetable extract", "plant extract",
            "essential oil", "oleoresin",
            "vegetable juice concentrate",
            "smoke flavor", "smoke flavour", "liquid smoke"
        ])
    }

    private static func containsAny(_ s: String, _ keywords: [String]) -> Bool {
        keywords.contains { s.contains($0) }
    }
}
