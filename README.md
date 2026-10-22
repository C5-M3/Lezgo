## Getting Started
Halo teman - teman semua, berikut tutorial untuk development nyaaa :D

## Install Software Update
Teman teman bisa update OS nya dulu yeaah (kalo ada)!

## Menjalankan aplikasi
- Clone terlebih dahulu github repository <br/>
```c
git clone https://github.com/C5-M3/MainProject.git
```
- Buka folder project <br/>
```c
cd Pawsona
```
## Github Projects Flow
1. Jangan lupa untuk selalu rely dan update [Github Projects](https://github.com/orgs/C5-M3/projects/1)
2. Di github project, pilih draft issue yang ingin dikerjakan, lalu bisa diklik titlenya
3. Di bagian kanan bawah, terdapat tombol convert to issue, jangan lupa untuk membuat memilih repo utama
4. Setelah issue berhasil tercreate, maka kita bisa memulai development phase dengan membuat branch dari issue tersebut, dengan klik "Create a branch" di bagian "Development" di kanan bawah issue tersebut.
5. Pastikan untuk ikuti peraturan dibawah untuk penamaan branch agar menjaga konsistensi <br>
6. Selanjutnya, kalian bisa melakukan `git checkout <nama-branch>` untuk memulai development di branch tersebut <br> 
7. Jika sudah selesai development di issue tersebut, lakukan commit dan push dengan penamaan commit sesuai conventional commit.
8. Selesai pengerjaan pada branch, bisa lanjut melakukan Pull Request dengan source branch adalah branch di issue tersebut, dan target branch adalah ke `staging` <br>

## Penamaan Branch
Branch names follow this structure:
```
<type>/<description>
```
Purpose Prefixes — describe the intent of the work:
- `feature/`: For new features (e.g., `feature/add-login-page`)
- `bugfix/`: For bug fixes (e.g., `bugfix/fix-header-bug`)
- `hotfix/`: For urgent fixes (e.g., `hotfix/security-patch`)
- `release/`: For branches preparing a release (e.g., `release/v1.2.0`)
- `chore/`: For non-code tasks like dependency, docs updates (e.g., `chore/update-dependencies`)
Trunk branches (`main`, `staging`, `dev`) do not require a prefix.

## Cara Commit / Push ke Github
```
git add .
git commit -m "feat: adding Home Page"
git push origin <nama-branch>
```
Harus menggunakan [`conventional commits`](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13)! <br/>
dengan format ``tipe: deskripsi``

<h3>Berikut Tipenya</h3>

- API or UI relevant changes
    - `feat` Commits, that add or remove a new feature to the API or UI
    - `fix` Commits, that fix an API or UI bug of a preceded `feat` commit
- `refactor` Commits, that rewrite/restructure your code, however do not change any API or UI behaviour
    - `perf` Commits are special `refactor` commits, that improve performance
- `style` Commits, that do not affect the meaning (white-space, formatting, missing semi-colons, etc)
- `test` Commits, that add missing tests or correcting existing tests
- `docs` Commits, that affect documentation only
- `build` Commits, that affect build components like build tools, dependencies, project version, ...
- `ci` Commits, that affect CI configuration files and scripts (e.g. GitHub Actions workflows, `.github/workflows`)
- `ops` Commits, that affect operational components like infrastructure, deployment, backup, recovery, ...
- `chore` Miscellaneous commits e.g. modifying `.gitignore`

## Cara Pull / Mengambil Data Terbaru dari Github ke Lokal
```c
git pull
git pull origin (branch) // untuk pull dari branch lain
```

## Cara rebase branch dari target branch
```c
git pull --rebase origin <nama-branch>
git push --force-with-lease
```
- Pastikan untuk meresolve semua conflict jika ada.