# 러너 기준선

이 문서는 현재 `Codex Pup` 러너를 MacDog의 기준 캐릭터 러너로 고정합니다.

## Codex Pup

- asset 경로: `Sources/MacDog/Resources/Runner`
- frame 파일: `pup-runner-0.png`부터 `pup-runner-7.png`
- 캐릭터 profile: `MacDogCharacterProfile.codexPup`
- frame 수: 8
- frame 크기: 80x48 px
- 메뉴바 status item 길이: 38 pt
- popover 크기: 320x540 pt
- 기본 러너 속도 기준: 주간 사용량

## 사용량 단계

| 단계 | 사용률 | 의미 |
| --- | ---: | --- |
| 여유 | 0-49% | 낮은 사용량 |
| 활발 | 50-79% | 보통 사용량 |
| 빠름 | 80-94% | 높은 사용량 |
| 질주 | 95-99% | 한도 근접 |
| 한도 | 100%+ | 한도 도달 |

## 검증

다음 명령으로 기준선을 확인합니다.

```sh
./script/verify_runner_baseline.sh
./script/build_and_run.sh --verify
```

러너 asset을 바꾸기 전에는 이 기준선과 변경 의도를 먼저 비교합니다.
