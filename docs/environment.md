# 실습 환경 구축

모든 스터디원은 같은 이미지(`gvenzl/oracle-free:23`, Oracle Database 23ai Free)와 같은 데이터로 실습합니다. 같은 SQL이면 Buffers 수치가 거의 같게 나오므로 PR에서 결과를 서로 비교할 수 있습니다.

## 1. 준비물
| | Windows | macOS |
|---|---|---|
| 필수 | WSL2 + Docker Desktop | Docker Desktop (Apple Silicon 포함) |
| 메모리 | Docker에 4GB 이상 할당 | 동일 |
| 디스크 | 여유 10GB 이상 | 동일 |
| 터미널 | Git Bash 또는 PowerShell | 기본 터미널 |

### Windows
1. 관리자 PowerShell에서 `wsl --install` 실행 후 재부팅
2. [Docker Desktop](https://www.docker.com/products/docker-desktop/) 설치. Settings → General에서 "Use the WSL 2 based engine"을 켭니다.
3. 확인: `docker run --rm hello-world`

## 2. DB 기동 (최초 1회 이미지 다운로드 약 1~2GB)
```bash
git clone https://github.com/<owner>/sqlp-study.git
cd sqlp-study
docker compose -f docker/compose.yml up -d
bash scripts/wait-db.sh          # "STUDY 계정 접속 OK" 가 나오면 준비 완료
```
- 포트를 바꾸려면 `docker/.env.example`을 `docker/.env`로 복사해서 `ORACLE_PORT`를 수정합니다.
- 최초 기동 때 `docker/init/01_create_study_user.sql`이 실행되어 **STUDY 계정(study/study)** 이 만들어집니다.

## 3. 접속 방법
### 권장: 컨테이너 안의 SQL*Plus
결과 형식이 모두 같아서 PR에 붙이기 좋습니다.
```bash
bash scripts/sql.sh                      # 대화형 (PowerShell: .\scripts\sql.ps1)
SQL> @weeks/week00-setup/01_setup.sql

bash scripts/run.sh weeks/week00-setup/02_lab.sql                     # 실행 결과를 화면에 출력
bash scripts/run.sh weeks/week00-setup/02_lab.sql weeks/week00-setup/submissions/<id>/lab.txt  # 파일로도 저장
```

### GUI 클라이언트 (SQL Developer, DBeaver 등)
| 항목 | 값 |
|---|---|
| Host | localhost |
| Port | 1521 |
| Service name | FREEPDB1 |
| User / Password | study / study |

GUI에서 실행계획을 볼 때도 `common/xplan.sql`의 쿼리(`DISPLAY_CURSOR ... 'ALLSTATS LAST'`)로 확인하세요. GUI의 "Explain Plan" 버튼은 **예상 계획**만 보여줍니다.

## 4. 자주 쓰는 명령
| 목적 | 명령 |
|---|---|
| 중지 / 재시작 | `docker compose -f docker/compose.yml stop` / `start` |
| 로그 | `docker logs -f sqlp-oracle` |
| TKPROF | `bash scripts/tkprof.sh <식별자>` |
| **완전 초기화** (데이터 삭제) | `docker compose -f docker/compose.yml down -v` |

## 5. 트러블슈팅
| 증상 | 원인 / 해결 |
|---|---|
| `port is already allocated` | 1521을 쓰는 다른 DB가 있음 → `docker/.env`에서 `ORACLE_PORT=1522` |
| wait-db 시간 초과, 컨테이너 재시작 반복 | Docker 메모리 부족 → 4GB 이상 할당 |
| Git Bash에서 `/workspace` 경로 오류 | 스크립트에 `MSYS_NO_PATHCONV=1`이 들어 있음. 직접 `docker exec`를 칠 때는 앞에 붙여서 실행 |
| `bad interpreter: /bin/bash^M` | CRLF 문제 → `git config core.autocrlf false` 후 다시 clone (`.gitattributes`가 LF를 강제함) |
| PowerShell 출력에서 한글 깨짐 | `scripts/*.ps1`은 UTF-8 출력을 설정해 둠. 직접 실행할 때는 `[Console]::OutputEncoding=[Text.Encoding]::UTF8` |
| STUDY 로그인 실패 | 볼륨이 init 스크립트 추가 전에 만들어졌을 수 있음 → `down -v` 후 재기동 |

## 6. Oracle 23ai Free 제약 (책과 수치가 다를 수 있는 이유)
- CPU 2스레드, 메모리(SGA+PGA) 2GB, 사용자 데이터 12GB로 제한됩니다.
- CDB/PDB 구조입니다. 책(10g/11g)은 non-CDB 기준이고, 버퍼 캐시는 PDB들이 공유합니다.
- 기본값으로 NOARCHIVELOG 모드라서 Direct Path 작업의 Redo가 매우 적게 나옵니다.
