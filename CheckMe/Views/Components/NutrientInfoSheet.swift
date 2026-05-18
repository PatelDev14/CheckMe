import SwiftUI

// MARK: - Nutrient Knowledge Base

struct NutrientKnowledge: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let role: String        // What it does in the body
    let dailyContext: String // How to think about the daily value
    let sources: String     // Common food sources
    let watchOut: String    // What to know if very high or low
}

extension NutrientKnowledge {
    static let all: [String: NutrientKnowledge] = [
        "Calories": NutrientKnowledge(
            name: "Calories",
            icon: "flame.fill",
            color: Color(red: 0.55, green: 0.45, blue: 0.95),
            role: "Calories are the unit of energy your body uses to power everything from breathing to exercise. They come from fat, carbohydrates, and protein.",
            dailyContext: "The standard reference is 2,000 calories per day, though your actual needs depend on age, size, and activity level.",
            sources: "All macronutrients contribute calories — fat provides 9 cal/g, carbs and protein each provide 4 cal/g.",
            watchOut: "Consistently consuming far more or far fewer calories than you burn will affect body weight over time."
        ),
        "Fat": NutrientKnowledge(
            name: "Total Fat",
            icon: "drop.fill",
            color: Color(red: 0.95, green: 0.55, blue: 0.10),
            role: "Fat is essential for absorbing fat-soluble vitamins (A, D, E, K), building cell membranes, and producing hormones. Not all fat is equal — unsaturated fats are generally heart-healthy.",
            dailyContext: "The daily reference is 78 g. Most health guidelines suggest fat should make up 20–35% of total calories.",
            sources: "Oils, nuts, seeds, avocado, fatty fish, dairy, and meat.",
            watchOut: "High saturated and trans fats are linked to elevated LDL cholesterol. Aim for mostly unsaturated sources."
        ),
        "Sat. Fat": NutrientKnowledge(
            name: "Saturated Fat",
            icon: "drop.halffull",
            color: Color(red: 0.95, green: 0.45, blue: 0.15),
            role: "Saturated fat is a type of fat solid at room temperature. High intake is associated with raising LDL ('bad') cholesterol, which can increase heart disease risk.",
            dailyContext: "The daily limit is 20 g. Most guidelines recommend keeping it under 10% of total calories.",
            sources: "Red meat, butter, cheese, coconut oil, palm oil, and processed foods.",
            watchOut: "Replacing saturated fats with unsaturated fats (olive oil, nuts) is generally beneficial for heart health."
        ),
        "Carbs": NutrientKnowledge(
            name: "Carbohydrates",
            icon: "bolt.fill",
            color: Color(red: 0.25, green: 0.55, blue: 0.95),
            role: "Carbohydrates are your body's preferred energy source. They break down into glucose, which fuels your brain, muscles, and organs.",
            dailyContext: "The daily reference is 275 g. Carbs should typically make up 45–65% of total calories for most people.",
            sources: "Grains, bread, pasta, rice, fruits, vegetables, legumes, and sugars.",
            watchOut: "Quality matters — whole grains and vegetables provide fiber and nutrients; refined carbs and added sugars offer less nutritional value."
        ),
        "Sugar": NutrientKnowledge(
            name: "Total Sugar",
            icon: "cube.fill",
            color: Color(red: 0.95, green: 0.25, blue: 0.25),
            role: "Sugar includes both naturally occurring sugars (from fruit and dairy) and added sugars. Added sugars contribute calories but few nutrients.",
            dailyContext: "No official daily value is set; most health organizations suggest limiting added sugar to under 50 g (about 12 tsp) per day.",
            sources: "Fruits, dairy (natural), plus candy, soft drinks, baked goods, and sauces (added).",
            watchOut: "High added sugar intake is linked to tooth decay, blood sugar spikes, and increased calorie intake. Check the 'added sugars' line if shown."
        ),
        "Protein": NutrientKnowledge(
            name: "Protein",
            icon: "dumbbell.fill",
            color: Color(red: 0.20, green: 0.80, blue: 0.45),
            role: "Protein is made of amino acids — the building blocks for muscles, enzymes, hormones, and immune cells. It also keeps you feeling full longer than carbs or fat.",
            dailyContext: "The daily reference is 50 g, but athletes and active people often need considerably more (1.2–2.0 g per kg of body weight).",
            sources: "Meat, poultry, fish, eggs, dairy, legumes, tofu, tempeh, and protein-fortified foods.",
            watchOut: "Most people in developed countries get enough protein. Variety of sources helps ensure all essential amino acids are covered."
        ),
        "Sodium": NutrientKnowledge(
            name: "Sodium",
            icon: "waveform.path",
            color: Color(red: 0.95, green: 0.80, blue: 0.15),
            role: "Sodium regulates fluid balance, blood pressure, and nerve signals. It's essential, but most people consume far more than needed.",
            dailyContext: "The daily limit is 2,300 mg (about 1 tsp of salt). The American Heart Association recommends staying under 1,500 mg for heart health.",
            sources: "Table salt, processed foods, canned goods, deli meats, sauces, and restaurant meals.",
            watchOut: "Chronic high sodium intake raises blood pressure and increases risk of heart disease and stroke. Check labels — it hides in surprising places."
        ),
        "Fiber": NutrientKnowledge(
            name: "Dietary Fiber",
            icon: "leaf.fill",
            color: Color(red: 0.30, green: 0.80, blue: 0.55),
            role: "Fiber feeds beneficial gut bacteria, slows sugar absorption, lowers LDL cholesterol, and keeps digestion regular. Most people get far too little.",
            dailyContext: "The daily goal is 28 g. Research consistently links high fiber intake to lower risk of heart disease, diabetes, and colorectal cancer.",
            sources: "Vegetables, fruits, whole grains, legumes, nuts, and seeds.",
            watchOut: "If you're increasing fiber, do it gradually and drink more water — sudden increases can cause bloating and gas."
        ),
        "Potassium": NutrientKnowledge(
            name: "Potassium",
            icon: "heart.fill",
            color: Color(red: 0.90, green: 0.40, blue: 0.60),
            role: "Potassium counteracts the blood-pressure-raising effects of sodium, supports heart rhythm, and helps muscles contract properly.",
            dailyContext: "The daily adequate intake is 4,700 mg. Most people fall well short of this — it's one of the most under-consumed minerals.",
            sources: "Bananas, potatoes, avocado, leafy greens, beans, and dairy.",
            watchOut: "Very high potassium is rarely a problem from food alone, but people with kidney disease should monitor intake carefully."
        ),
        "Calcium": NutrientKnowledge(
            name: "Calcium",
            icon: "staroflife.fill",
            color: Color(red: 0.40, green: 0.70, blue: 0.95),
            role: "Calcium is the main mineral in bones and teeth, and is also vital for muscle contraction, nerve signalling, and blood clotting.",
            dailyContext: "The daily goal is 1,300 mg. Inadequate calcium over time can lead to weakened bones (osteoporosis).",
            sources: "Dairy products, fortified plant milks, tofu, leafy greens (kale, bok choy), and canned sardines.",
            watchOut: "Vitamin D is needed to absorb calcium — having one without the other limits the benefit."
        ),
        "Iron": NutrientKnowledge(
            name: "Iron",
            icon: "circle.hexagongrid.fill",
            color: Color(red: 0.85, green: 0.35, blue: 0.20),
            role: "Iron is essential for making haemoglobin, the protein in red blood cells that carries oxygen from your lungs to every cell in your body.",
            dailyContext: "The daily goal is 18 mg. Iron deficiency is one of the most common nutrient deficiencies worldwide, especially in women and vegetarians.",
            sources: "Red meat, liver, shellfish, legumes, tofu, spinach, and fortified cereals.",
            watchOut: "Plant-based iron (non-haem) is absorbed less efficiently. Consuming it with vitamin C significantly boosts absorption."
        ),
        "Vitamin A": NutrientKnowledge(
            name: "Vitamin A",
            icon: "eye.fill",
            color: Color(red: 0.95, green: 0.65, blue: 0.10),
            role: "Vitamin A supports vision (especially night vision), immune function, and cell growth. It also plays a key role in skin and reproductive health.",
            dailyContext: "The daily goal is 900 mcg for adults. It comes in two forms: preformed (from animal foods) and beta-carotene (from plants).",
            sources: "Liver, dairy, eggs (preformed); carrots, sweet potato, spinach, and red peppers (beta-carotene).",
            watchOut: "Preformed vitamin A (from supplements or liver) can be toxic in large amounts. Beta-carotene from plants is safe — the body converts only what it needs."
        ),
        "Vitamin C": NutrientKnowledge(
            name: "Vitamin C",
            icon: "sparkles",
            color: Color(red: 0.95, green: 0.75, blue: 0.20),
            role: "Vitamin C is a powerful antioxidant that supports immune function, collagen production (for skin and wound healing), and the absorption of plant-based iron.",
            dailyContext: "The daily goal is 90 mg. Deficiency causes scurvy — rare today, but low levels are more common than people realise.",
            sources: "Citrus fruits, bell peppers, kiwi, strawberries, broccoli, and tomatoes.",
            watchOut: "Vitamin C is water-soluble — excess is excreted. Very high doses from supplements may cause digestive upset."
        ),
        "Vitamin D": NutrientKnowledge(
            name: "Vitamin D",
            icon: "sun.max.fill",
            color: Color(red: 0.95, green: 0.85, blue: 0.30),
            role: "Often called the 'sunshine vitamin', Vitamin D regulates calcium absorption for bone health, supports immune function, and influences mood and inflammation.",
            dailyContext: "The daily goal is 20 mcg (800 IU). Deficiency is extremely common, especially in northern climates and among people who spend little time outdoors.",
            sources: "Sun exposure, fatty fish, fortified milk and plant milks, egg yolks, and mushrooms exposed to UV light.",
            watchOut: "Vitamin D is fat-soluble and can build up to toxic levels from supplements — though this requires very high doses. Many people benefit from a moderate supplement."
        ),
    ]
}

// MARK: - Sheet View

struct NutrientInfoSheet: View {
    let knowledge: NutrientKnowledge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero icon
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(knowledge.color.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: knowledge.icon)
                                .font(.system(size: 34))
                                .foregroundStyle(knowledge.color)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    infoBlock(title: "What it does", body: knowledge.role)
                    infoBlock(title: "Daily Value context", body: knowledge.dailyContext)
                    infoBlock(title: "Food sources", body: knowledge.sources)
                    infoBlock(title: "Good to know", body: knowledge.watchOut)
                }
                .padding(20)
            }
            .navigationTitle(knowledge.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(knowledge.color)
                .tracking(0.8)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
