# 효과음 (전부 CC0 — 상용 이용·크레딧 불필요)

| 폴더 | 출처 | 개수 | 내용 |
|---|---|---|---|
| `kenney_impact/` | Kenney Impact Sounds (License.txt 동봉) | 130 | 금속·나무·유리·천·발소리·펀치·타격 임팩트 |
| `oga_100_v2/` | OpenGameArt "100 CC0 SFX #2" | 100 | 타격·금속·유리·문·발소리(나무/젖은)·돌·공기·스위치·앰비언트 루프 |

## 사용 제안 (sound.gd의 합성음 대체)
- 유령탄 발사: kenney `impactSoft*` 또는 oga `air` + 기존 합성 톤 레이어
- 연발총·산탄총: 총성 전용 팩이 아직 없음 → 기존 합성 `rifle`을 유지하되 kenney `impactMetal_heavy*`를 레이어해 두께 추가 (추후 총성 팩 조달)
- 근접 타격(망치): kenney `impactPunch*`, `impactWood_heavy*`
- 피격(플레이어): kenney `impactSoft_heavy*` + 낮은 톤
- 적 사망: kenney `impactBell*`(뼈 부서짐 대용) / oga `sfx100v2_hit*`
- 잡몹 접근: oga `footstep_wet*` 다중 재생 (무리 압박감)
- 문 통과: oga `door*`
- 빙의 성공: 기존 합성 `possess` 유지 + kenney `impactGlass_light*` 레이어
- 앰비언트: oga `loop_ambient*` 저음량 루프

## 부족한 것 (추후)
총성, 마법(화염·얼음·번개), 보스 전용, 음악.
