# 🔥 FireSafeXR

**A VR/XR Fire-Safety Emergency Training & Assessment Simulator — built in Godot 4.7**

FireSafeXR puts the trainee in the role of a first responder working through a realistic residential fire incident: assess the scene, select the correct firefighting tools, suppress fires using proper technique, locate and rescue a trapped victim, and evacuate — all while the system silently scores every decision and produces a performance report.

---

## ✨ Overview

Traditional fire-safety training is hard to run at scale: live burns are expensive and dangerous, and slideshows don't build muscle memory. FireSafeXR recreates the decision-making of an emergency response in a safe, repeatable 3D simulation. The trainee must apply real procedures — **correct extinguisher class for the fire type**, the **PASS technique** (Pull, Aim, Squeeze, Sweep), thermal scanning to find victims through smoke, and safe evacuation — and the built-in assessment engine grades them on both success and safety mistakes.

## 🎮 Core Features

- **Staged incident scenario** — the simulation progresses through distinct phases, each tracked independently:
  1. **Exterior Assessment** — size up the scene and collect the toolkit from the fire truck
  2. **Interior Search** — enter the structure and navigate through smoke
  3. **Fire Suppression** — locate and extinguish the living-room and kitchen fires
  4. **Victim Location** — use the thermal camera to find a victim through a wall / smoke
  5. **Rescue & Evacuation** — breach the bedroom door, rescue the victim, and reach the evacuation zone
- **Fire-class–aware suppression** — fires are typed (Class A, Class B grease, etc.) and require the **correct extinguisher**. Using water on a grease fire is flagged as a dangerous error.
- **Realistic extinguisher handling** — the extinguisher models pin-pull state, finite agent reserve, spray particles, and a **sweep-motion check** so the trainee must aim and sweep correctly rather than just point and hold.
- **Firefighter toolkit** — switchable tools: **Thermal Camera**, **ABC Dry-Chemical Extinguisher**, **Water Hose**, and **Halligan bar** (forced-entry / door breaching).
- **Dynamic fire behavior** — fires flicker, flare, and grow over time if left unattended, with live lighting and smoke.
- **Automated assessment engine** — `TrainingManager` records completion of every stage, timing, and penalties (e.g. wrong extinguisher, skipped thermal scan) and emits a structured performance report on completion.
- **Investigation & inspection environments** — additional rooms (evidence hub, chemistry lab, victim's study) with interactable, inspectable props for scenario and evidence-based training extensions.

## 🕹️ Controls

| Action | Input |
|---|---|
| Move | `W` `A` `S` `D` |
| Look | Mouse |
| Interact / pick up | `E` |
| Pull extinguisher pin | `Q` |
| Spray extinguisher | `Left Mouse` / `Space` |

## 🛠️ Tech Stack

- **Engine:** [Godot](https://godotengine.org/) **4.7** (Forward+ renderer)
- **Language:** GDScript
- **Rendering:** real-time 3D with dynamic shadows (4096 shadow atlas), soft shadows, MSAA 3D
- **Project scale:** 13 gameplay scripts, 20 scenes (player, props, rooms, facilities)

## 🚀 Getting Started

### Prerequisites
- [Godot Engine 4.7](https://godotengine.org/download) or newer (standard build — no C#/.NET required)

### Run the project
1. Clone the repository:
   ```bash
   git clone https://github.com/ragulspiygen-cmyk/FireSafeXR.git
   ```
2. Open **Godot 4.7**, click **Import**, and select the `project.godot` file in the cloned folder.
3. Press **F5** (or the ▶ Play button) to launch. The main scene is `scenes/main.tscn`.

## 📁 Project Structure

```
FireSafeXR/
├── project.godot              # Engine configuration & input map
├── scenes/
│   ├── main.tscn              # Entry scene (wired incident scenario)
│   ├── player/                # Player rig & camera
│   ├── props/                 # Extinguisher, hose, thermal cam, victim, evidence props
│   ├── rooms/                 # Chemistry lab, evidence hub, victim's study
│   └── facility/              # House (2BHK) and apartment layouts
└── scripts/
    ├── main_game.gd           # Scene wiring & signal orchestration
    ├── training_manager.gd    # Assessment, stage tracking & scoring
    ├── player_controller.gd   # Movement, look, interaction, smoke handling
    ├── firefighter_tools.gd   # Tool switching (thermal / extinguisher / hose / halligan)
    ├── fire_extinguisher.gd   # Pin, reserve, spray & sweep mechanics
    ├── fire_hazard.gd         # Fire class, health, growth & suppression logic
    ├── victim.gd              # Rescue logic
    ├── interactable.gd        # Inspectable-object base class
    └── ...                    # Doors, lights, props
```

## 📊 Assessment Model

The `TrainingManager` tracks the full incident timeline and produces a report covering:

- **Stage completion** — toolkit pickup, house entry, each fire extinguished, thermal scan used, door breached, victim rescued, evacuation complete
- **Safety penalties** — water on a grease (Class B) fire, sub-optimal tool choice on the living-room fire, skipped thermal scan
- **Time to completion**

This turns a playthrough into a measurable, repeatable competency check rather than a one-off demo.

## 🗺️ Roadmap

- Native VR/XR head-mounted-display and motion-controller support (OpenXR)
- Expanded fire-class library and additional incident scenarios
- On-screen debrief UI summarizing the assessment report
- Multi-trainee / instructor review mode

## 👥 Author

Developed by [**@ragulspiygen-cmyk**](https://github.com/ragulspiygen-cmyk) as an AR/VR course project.

## 📄 License

Released under the [MIT License](LICENSE).
