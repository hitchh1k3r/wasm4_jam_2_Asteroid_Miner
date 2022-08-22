### **A game made for** [**WASM-4 Jam #2**](https://itch.io/jam/wasm4-v2)

The year is 20X7. Galactic explorers have recently discovered an exotic material that can be easily converted into any form of energy or matter. They have named it "Physic," and an ongoing war over control of the asteroid belt where it is located rages. You are an ace pilot trying to collect as much physic as possible, good luck!

The game draws inspiration mainly from [Asteroids (1979)](https://en.wikipedia.org/wiki/Asteroids_(video_game)) and [Bitfighter](https://bitfighter.org/), though many features that would have made it more bitfighter-like were cut due to time.

## **Controls**

- Flight:
  - Pitch / Yaw - **Arrows**
  - Speed / Roll - **X + Arrows**
- Weapons:
  - Laser - **Z**
  - Mine - **X + Z** (costs 100 physic)
- WASM-4 Menu - **Enter**

## **How To Play**

- To **win** you must **collect** more " **physic**" than the opposing team. When an **asteroid is damaged** (shot with **laser** , or **crashed** into by a ship or another asteroid) it will leave a **short lived cloud** behind. Moving near it will** store it in your ship **. When you are carrying "physic" and get** near **your** team's space station **, it will transfer and** count towards your score**.
- You can **practice** the game by starting it **single player** , but to really play the game **you will need a friend or three** to join you over **WASM-4's NETPLAY**. Press " **Enter**" then select " **COPY NETPLAY URL**" and **send your friend(s) the link**.
- The **world loops** like in the original asteroids. You may **see your own ships** trail in front of you. Try not to **chase your own tail** when hunting other ships ^\_^.
- The game can be played on **lower power devices** if the starting **asteroid count** is set **low enough** , if the game is **lagging** try **turning down "Num Asteroids."**
- If your ship has at least **100 physic** (not your base, there is an indicator) you can **place a mine** behind your ship (good for if you are being pursued). The mine will **activate** once there are **no ships** in its damage radius. If anyone **gets too close** it will **explode** everything near it.
- Your ship **can only move** as **fast** as it **has health** , it will **always slowly heal** , and **heal faster** when near your team's **space station**.

## **Credits**

- Design, Programming, Art - [**HitchH1k3r**](https://hitchh1k3r.itch.io/)
- Engine - [**WASM-4**](https://wasm4.org/)
- Programming Language - [**Odin**](https://odin-lang.org/)
- Song - Adaptation of [**Oh Shenandoah**](https://en.wikipedia.org/wiki/Oh_Shenandoah)

## **Known Bugs**

- **Every game ends in a "Draw"** regardless of which team wins
- **Y-Inversion** option **cut for time** (sorry)
- **Music is too fast** when the game first starts ( **it will calm down** once the game starts proper)
- The **story** screens and **tutorial** were **cut for time**
- **Respawn timer** is broken so you can respawn **instantly for free** (was supposed to be 30 seconds, or 60 team physic per second left)
- **Laser** shots do **not travel far** enough
- **No player** individual **music mute** options (it's everyone or no one)
- Some **gameplay settings** have their **minimum and maximum** values **messed up**
- " **Physic To Win**" and " **Time Limit**" are **missing** their " **Unlimited**" options (though Time Limit when moving left is messed up, and if you set it to a negative value it will be effectively unlimited time)
- Most of the **sound effects** are **not implemented** , most notably **mine sound effects** (place, activate, explode)
- After game over, starting a **new game** will **not reset** the **player ships**
