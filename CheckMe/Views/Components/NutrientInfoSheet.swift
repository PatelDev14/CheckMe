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
        "Water": NutrientKnowledge(
            name: "Water",
            icon: "drop.fill",
            color: Color(red: 0.25, green: 0.55, blue: 0.95),
            role: "Water is the primary component of most beverages and makes up around 60% of the human body. It carries nutrients to cells, regulates temperature, and supports every metabolic process.",
            dailyContext: "General guidelines suggest roughly 2–3 litres of total fluid per day from all sources. Beverages, soups, and water-rich foods all count.",
            sources: "Plain water, sparkling water, tea, coffee, juice, milk, and water-rich foods such as cucumber, watermelon, and lettuce.",
            watchOut: "Beverages high in water can still carry significant calories from sugar or fat — always check the full nutrition panel alongside the serving size."
        ),
        "Starch": NutrientKnowledge(
            name: "Net Carbs",
            icon: "bolt.fill",
            color: Color(red: 0.78, green: 0.52, blue: 0.30),
            role: "Starch is a complex carbohydrate made of long glucose chains. It digests more slowly than simple sugars, providing a steadier release of energy.",
            dailyContext: "Starch is the main carbohydrate in most diets. There is no separate daily value — it falls under total carbohydrates (275 g reference). Whole-grain starches also deliver fiber and micronutrients.",
            sources: "Bread, pasta, rice, oats, potatoes, corn, legumes, and most grain-based products.",
            watchOut: "Refined starches (white bread, white rice) digest quickly and spike blood sugar faster than whole-grain versions. Choose whole grains where possible."
        ),
        "Calories": NutrientKnowledge(
            name: "Calories",
            icon: "flame.fill",
            color: Color(red: 0.95, green: 0.60, blue: 0.10),
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

// MARK: - Extra knowledge (gut + pairing) keyed by nutrient name

private enum NutrientExtra {
    static let gutImpact: [String: String] = [
        "Calories":   "Excess calories are stored as fat if not burned. The source matters — calories from fiber-rich carbs or lean protein are processed differently than those from refined sugar or saturated fat.",
        "Fat":        "Slows digestion and boosts satiety. Healthy fats support the gut lining and help reduce inflammation; excessive saturated fat can shift gut bacteria toward less beneficial species.",
        "Sat. Fat":   "High intake may promote gut inflammation and reduce microbiome diversity. Swapping some saturated fat for unsaturated sources benefits both heart and gut health.",
        "Carbs":      "Primary fermentation fuel for gut bacteria. Complex carbs from whole grains feed beneficial microbiome populations; refined carbs digest fast, leaving little for the microbiome.",
        "Sugar":      "Simple sugars digest quickly; excess intake feeds harmful gut bacteria and can contribute to dysbiosis (microbial imbalance) over time. Natural sugars in fruit come with fiber that slows this effect.",
        "Protein":    "Broken down into amino acids in the small intestine. Some undigested protein reaches the colon where bacteria ferment it — excessive amounts can produce ammonia and other by-products.",
        "Fiber":      "Prebiotic fuel for beneficial gut bacteria — fermented into short-chain fatty acids (SCFAs) like butyrate that protect the colon lining and support the immune system.",
        "Sodium":     "High sodium intake can reduce microbiome diversity and alter gut motility, contributing to bloating and water retention in sensitive individuals.",
        "Potassium":  "Supports smooth muscle function along the digestive tract. Adequate intake helps maintain healthy bowel regularity and reduces cramping.",
        "Calcium":    "Binds to excess fat and bile acids in the gut, helping to carry them out of the body — this may reduce colon cancer risk.",
        "Iron":       "Can irritate the gut lining in high doses. Unabsorbed iron in the colon feeds some opportunistic bacteria; food-based iron is generally gentler than supplements.",
        "Vitamin A":  "Critical for maintaining the integrity of the gut mucosal lining — the protective barrier between gut contents and the bloodstream.",
        "Vitamin C":  "Its antioxidant properties protect gut cells from oxidative damage. Also enhances iron absorption and supports the connective tissue of the gut wall.",
        "Vitamin D":  "Regulates immune cells in the gut lining and helps maintain the intestinal barrier. Deficiency is linked to increased gut permeability ('leaky gut').",
    ]

    static let pairingTip: [String: String] = [
        "Calories":   "Balance calorie-dense foods with fiber-rich vegetables and protein to slow absorption and sustain energy longer.",
        "Fat":        "Pair with fat-soluble vitamins A, D, E, and K — fat is required for their absorption. Olive oil on a salad dramatically boosts the nutrients you absorb.",
        "Sat. Fat":   "Balance with unsaturated fats (avocado, olive oil, nuts) and high-fiber foods to offset the gut impact.",
        "Carbs":      "Combine with protein and healthy fat to slow glucose release and prevent energy spikes and crashes.",
        "Sugar":      "Pair with fiber to slow absorption. Avoid high-sugar foods on an empty stomach — the rapid spike is harder on blood sugar control.",
        "Protein":    "Vitamin C-rich foods boost plant-based protein absorption. Eating protein with complex carbs helps direct amino acids to muscle repair.",
        "Fiber":      "Drink more water when increasing fiber — it needs fluid to move smoothly through the gut and prevent constipation.",
        "Sodium":     "Potassium-rich foods (bananas, sweet potato, avocado) help counterbalance sodium's blood pressure effects.",
        "Potassium":  "Pairs well with magnesium-rich foods — both work together to support muscle function, nerve signaling, and healthy blood pressure.",
        "Calcium":    "Always pair with Vitamin D — without it, your body absorbs very little calcium regardless of how much you consume.",
        "Iron":       "Eat with Vitamin C to boost non-haem iron absorption up to 3×. Avoid coffee, tea, or dairy within an hour — tannins and calcium block iron uptake.",
        "Vitamin A":  "Needs a small amount of dietary fat to be absorbed. A drizzle of oil on roasted vegetables dramatically improves uptake.",
        "Vitamin C":  "Pairs powerfully with iron-rich foods. Also regenerates Vitamin E after it neutralises free radicals — the two antioxidants work as a team.",
        "Vitamin D":  "Best absorbed with a fatty meal. Vitamin K2 works synergistically — it helps direct the calcium that Vitamin D absorbs to bones rather than arteries.",
    ]

    static let deficiencySigns: [String: String] = [
        "Calories":  "Persistent fatigue, difficulty concentrating, feeling constantly cold, muscle loss over time, and poor wound healing — your body is running below its energy needs.",
        "Fat":       "Dry, flaky skin and dull hair, poor wound healing, fatigue, hormonal disruption, and difficulty absorbing vitamins A, D, E, and K.",
        "Sat. Fat":  "Rarely a deficiency concern — most diets contain enough. Extremely low fat intake overall is more likely to cause issues than low saturated fat specifically.",
        "Carbs":     "Brain fog, irritability, fatigue, and reduced exercise performance. Very low carb intake forces the body into ketosis, which some people tolerate well, others do not.",
        "Sugar":     "Not a deficiency concern — your body makes all the glucose it needs from complex carbohydrates, protein, and fat.",
        "Protein":   "Muscle wasting, slow wound and injury healing, frequent illness due to weakened immunity, thinning hair and nails, and fluid retention (oedema in severe cases).",
        "Fiber":     "Chronic constipation, blood sugar spikes after meals, elevated LDL cholesterol, and reduced microbiome diversity — all linked to higher long-term disease risk.",
        "Sodium":    "Muscle cramps, persistent headache, nausea, confusion, and extreme fatigue. True deficiency is rare — far more people consume too much than too little.",
        "Potassium": "Muscle weakness and cramping (especially legs), constipation, heart palpitations, fatigue, and high blood pressure. Common in people who eat few fruits and vegetables.",
        "Calcium":   "Muscle spasms and cramps, numbness or tingling in hands and feet, brittle nails, and — over years — weakened bones leading to osteoporosis and fracture risk.",
        "Iron":      "Fatigue even with adequate sleep, pale skin and gums, brittle or spoon-shaped nails, brain fog, shortness of breath on light exertion, and feeling cold. Iron deficiency anaemia is the world's most common nutritional deficiency.",
        "Vitamin A": "Difficulty seeing in dim light (night blindness) is often the first sign. Also dry eyes, dry skin, frequent respiratory infections, and slow wound healing.",
        "Vitamin C": "Fatigue, bruising easily from minor bumps, slow wound healing, and dry skin. Severe deficiency causes scurvy — bleeding gums, joint pain, and loose teeth.",
        "Vitamin D": "Bone ache and tenderness, muscle weakness, fatigue that sleep doesn't fix, frequent colds and infections, and low mood. Deficiency is extremely common, especially in northern latitudes or with limited sun exposure.",
    ]
}

// MARK: - Sheet View

struct NutrientInfoSheet: View {
    let knowledge: NutrientKnowledge
    /// Optional: pass the 0–1 fraction of the daily value from the calling context.
    /// When provided, a visual daily-value gauge is shown in the header.
    var dailyValueFraction: Double? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false
    @State private var barProgress: CGFloat = 0

    // MARK: - Layout config

    private let blocks: [(icon: String, label: String, body: KeyPath<NutrientKnowledge, String>)] = [
        ("info.circle.fill",       "What it does",          \.role),
        ("chart.bar.xaxis",        "Daily Value context",   \.dailyContext),
        ("leaf.fill",              "Food sources",          \.sources),
        ("exclamationmark.circle", "Good to know",          \.watchOut),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroSection
                        .staggerReveal(revealed, delay: 0.0)

                    if let fraction = dailyValueFraction {
                        dailyValueBar(fraction: fraction)
                            .staggerReveal(revealed, delay: 0.08)
                    }

                    ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                        infoBlock(
                            icon: block.icon,
                            title: block.label,
                            body: knowledge[keyPath: block.body]
                        )
                        .staggerReveal(revealed, delay: Double(index) * 0.07 + 0.14)
                    }

                    // Gut impact block
                    if let gut = NutrientExtra.gutImpact[knowledge.name] {
                        infoBlock(icon: "microbe.fill", title: "Gut & Digestion", body: gut)
                            .staggerReveal(revealed, delay: 0.14 + Double(blocks.count) * 0.07)
                    }

                    // Deficiency signs block
                    if let def = NutrientExtra.deficiencySigns[knowledge.name] {
                        infoBlock(icon: "battery.0percent", title: "Signs of low intake", body: def)
                            .staggerReveal(revealed, delay: 0.14 + Double(blocks.count + 1) * 0.07)
                    }

                    // Pairing tip block
                    if let pair = NutrientExtra.pairingTip[knowledge.name] {
                        infoBlock(icon: "fork.knife", title: "Pairs well with", body: pair)
                            .staggerReveal(revealed, delay: 0.14 + Double(blocks.count + 2) * 0.07)
                    }

                    Spacer(minLength: 24)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(knowledge.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(knowledge.color)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                    revealed = true
                }
                if let fraction = dailyValueFraction {
                    withAnimation(.easeInOut(duration: 0.85).delay(0.25)) {
                        barProgress = CGFloat(min(fraction, 1.0))
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(knowledge.color.opacity(0.12))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(knowledge.color.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                Image(systemName: knowledge.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(knowledge.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(knowledge.name)
                    .font(.title3).fontWeight(.bold)
                Text("Tap any section to learn more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(knowledge.color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Daily Value Bar

    private func dailyValueBar(fraction: Double) -> some View {
        let pct = Int(min(fraction * 100, 999))
        let barColor: Color = fraction < 0.5 ? knowledge.color : fraction < 1.0 ? .orange : .red
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(barColor)
                    .font(.subheadline)
                Text("Daily Value")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(pct)%")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 10)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [barColor.opacity(0.7), barColor],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * barProgress, height: 10)
                }
            }
            .frame(height: 10)

            Text(fraction >= 1.0
                 ? "Over your daily limit — consider this product as part of your full day."
                 : "This serving covers \(pct)% of the recommended daily amount.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(barColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Info Block

    private func infoBlock(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Colored left accent bar — use RoundedRectangle so it stretches naturally
            RoundedRectangle(cornerRadius: 1.5)
                .fill(knowledge.color.opacity(0.5))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(knowledge.color)
                        .frame(width: 16)
                    Text(title.uppercased())
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(knowledge.color)
                        .tracking(0.6)
                }
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
            }
            // maxWidth forces the VStack to fill all remaining width so text
            // wraps flush to the right edge instead of hugging its content.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stagger animation helper

private extension View {
    func staggerReveal(_ revealed: Bool, delay: Double) -> some View {
        self
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 6)
            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay), value: revealed)
    }
}
