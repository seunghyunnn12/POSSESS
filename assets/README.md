# 캐릭터 에셋 (KayKit, CC0 — 상업 이용·크레딧 불필요)

리깅 + 애니메이션 내장 GLB. Godot에 드래그하면 AnimationPlayer 클립까지 자동 임포트됨.

## 역할 매핑 (GDD 기준)

| 게임 역할 | 추천 모델 | 비고 |
|---|---|---|
| 브루트 (근접 거구) | `adventurers/Barbarian.glb` 또는 `skeletons/Skeleton_Warrior.glb` | 2H 무기 휘두르기 애니 내장 |
| 병사 (원거리) | `skeletons/Skeleton_Rogue.glb` + `props/skeletons/Skeleton_Crossbow.gltf` | 석궁 = 총 대체. 사격 애니 내장 |
| 술사 (원거리 마법) | `adventurers/Mage.glb` 또는 `skeletons/Skeleton_Mage.glb` | staff/spellcast 애니 |
| 잡몹 | `skeletons/Skeleton_Minion.glb` | |
| 예비 | `adventurers/Knight.glb`, `Rogue.glb`, `Rogue_Hooded.glb` | |

- 무기·방패 프롭은 `props/` (본에 어태치하는 방식, 캐릭터 GLB 내 소켓 참고)
- 유령(플레이어 본체)은 1인칭이라 모델 불필요 (손/이펙트만) — 나중에 Meshy로 제작 예정
- 세계관 참고: 팩이 판타지 톤이므로 "봉인된 지하도시 + 석궁/마법" 테마와 맞음. 총기 테마로 갈 경우 이 에셋들은 프로토타입 대역으로 쓰고 추후 교체.
