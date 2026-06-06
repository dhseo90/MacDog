# 메뉴바 캐릭터 기준선

이 문서는 현재 `Codex Pup` 메뉴바 캐릭터 표시 계약을 고정합니다.

## Codex Pup

- 메뉴바 이미지는 `Sources/MacDog/Resources/DesktopPet/pup-run-right-0.png`부터 `pup-run-right-7.png`까지의 현재 데스크톱 펫 프레임을 직접 축소해 사용합니다.
- 캐릭터 profile: `MacDogCharacterProfile.codexPup`
- 메뉴바 source pose: `MacDogCharacterProfile.codexPup.menuBarImage.sourcePose == .runRight`
- frame 수: 8
- source frame 크기: 192x204 px
- 메뉴바 status item 길이: 38 pt
- popover 크기: 370x408 pt
- 기본 속도 기준: 주간 사용량

## 구성

- 메뉴바, 데스크톱 펫, 탭 버튼은 하나의 현재 캐릭터 세트에서 파생합니다.
- 메뉴바 이미지는 `MacDogCharacterProfile.codexPup`이 지정한 데스크톱 펫 pose를 사용합니다.
- 메뉴바 상태 강조는 현재 캐릭터 이미지 위에 상태 배지만 추가합니다.

## 검증

다음 명령으로 기준선을 확인합니다.

```sh
./script/verify_menu_bar_character.sh
./script/verify_character_profile.sh
```

메뉴바 캐릭터 표시 방식을 바꾸기 전에는 이 기준선과 변경 의도를 먼저 비교합니다.
