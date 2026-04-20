# AGENTS.md

# Design System Strategy: The Curated Gallery


## 1. Overview & Creative North Star


The Creative North Star for this design system is **"The Digital Curator."** 


 


This is not a standard e-commerce platform; it is a high-end, editorialized museum experience for the digital age. We move away from the "boxy" density of traditional marketplaces in favor of expansive white space, intentional asymmetry, and tonal depth. The goal is to make every virtual asset feel like a physical masterpiece under gallery lighting. 


 


We reject "web-standard" crutches like 1px borders and heavy drop shadows. Instead, we use **Tonal Layering** and **Atmospheric Perspective** to guide the eye. The interface should feel like layered sheets of heavy-weight paper and frosted glass, creating a tactile, premium environment that recedes to let the assets shine.


 


---


 


## 2. Colors & Surface Philosophy


 


### The Pallete logic


The palette is rooted in a "Cool Slate" spectrum to maintain a sophisticated, neutral backdrop that allows the **Rarity Gemstone Tones** to pop with intent.


 


*   **Base Canvas (`surface`):** `#F8FAFC`. This is your floor.


*   **Sectioning (`surface-container`):** `#F1F5F9`. Used to define large content areas without lines.


*   **Active Cards (`surface-container-lowest`):** `#FFFFFF`. The highest point of elevation; these should feel "lit" from above.


 


### The "No-Line" Rule


**Prohibit 1px solid borders for sectioning.** 


Structural boundaries must be defined solely through background color shifts. If a sidebar needs to be separated from a main feed, use `surface-container-low` against the `surface` background. If an element needs to be grouped, use a container with a `0.35rem` (Scale 1) shift in tonal value.


 


### Surface Hierarchy & Nesting


Treat the UI as a physical stack. 


1.  **Level 0 (The Gallery Wall):** `surface` (#F8FAFC)


2.  **Level 1 (The Pedestal):** `surface-container` (#F1F5F9) 


3.  **Level 2 (The Asset Case):** `surface-container-lowest` (#FFFFFF)


 


### The Glass & Gradient Rule


To achieve a "signature" look, use **Glassmorphism** for floating navigation and overlays. Apply `surface-container-lowest` at 70% opacity with a `20px` backdrop blur. 


*   **Signature Gradient:** For Primary Actions, use a linear gradient (135°) from `primary` (#1E40AF) to `secondary` (#3B82F6). This provides a "soul" to the UI that flat colors cannot replicate.


 


---


 


## 3. Typography: The Editorial Voice


 


Hierarchy is used to create a rhythmic, magazine-like flow.


 


*   **Display & Headlines (Plus Jakarta Sans):** These are your "Gallery Signs." Use `display-lg` for hero moments with tight letter spacing (-0.02em) to create an authoritative, bespoke feel.


*   **Body (Inter):** The "Curator’s Notes." Inter provides maximum readability for descriptions and metadata. Keep line heights generous (1.6) to maintain the airy, premium feel.


*   **Data & Numbers (Space Grotesk):** The "Inventory Code." Use this for all prices, rarity percentages, and counts. The tabular figures of Space Grotesk lend a technical, precise "restricted file" aesthetic to the assets.


 


---


 


## 4. Elevation & Depth


 


### The Layering Principle


Depth is achieved by stacking `surface-container` tiers. Place a `surface-container-lowest` card (Pure White) on a `surface-container-low` section. This creates a soft "lift" that feels integrated into the environment.


 


### Ambient Shadows


Shadows are a last resort. When a floating state is required (e.g., a dragged asset), use an **Ambient Shadow**:


*   **Blur:** 40px - 60px


*   **Opacity:** 4% - 6%


*   **Color:** Derived from `on-surface` (#191C1E). It should look like a soft glow of darkness, not a smudge.


 


### The "Ghost Border" Fallback


If contrast ratios require a boundary for accessibility, use a **Ghost Border**: `outline-variant` (#C4C5D5) at 15% opacity. It should be felt, not seen.


 


---


 


## 5. Components


 


### Buttons


*   **Primary Action:** `primary` to `secondary` gradient. Radius: `0.375rem` (md). No border. White text.


*   **Secondary:** `surface-container-high` background with `primary` text. This "recedes" into the UI until hovered.


*   **Tertiary:** Ghost style. No background, `primary` text, underlined only on hover.


 


### Asset Cards (The "Exhibit")


*   **Structure:** Pure White (`#FFFFFF`) background.


*   **Rarity Indicator:** A `2px` bottom accent bar using the Gemstone Tones (e.g., `Covert` #E11D48) or a `5px` dot in the top-right corner.


*   **Spacing:** Use `spacing-5` (1.7rem) for internal padding to give the asset "breathing room."


 


### Inputs & Fields


*   **Style:** Minimalist. No bottom line or full border. Use a subtle background shift to `surface-container-highest` (#E0E3E5). 


*   **Focus State:** Transition the background to `surface-container-lowest` and add a `2px` `secondary-fixed` bottom-only accent.


 


### Chips (Rarity & Tags)


*   **Style:** Pill-shaped (`rounded-full`). 


*   **Color:** Use
