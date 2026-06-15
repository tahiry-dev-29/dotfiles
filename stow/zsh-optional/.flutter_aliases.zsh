# ==============================================================================
# 10. FLUTTER 💙
# ==============================================================================
if command -v flutter >/dev/null 2>&1; then
alias f='flutter'
alias fr='flutter run'
alias frd='flutter run --debug'
alias frr='flutter run --release'
alias frp='flutter run --profile'
alias frl='flutter run -d linux'
alias frw='flutter run -d web-server --web-port 4200'
alias frc='flutter run -d chrome'

alias fpg='flutter pub get'
alias fpu='flutter pub upgrade --major-versions'
alias fpa='flutter pub add'
alias fprm='flutter pub remove'
alias fpout='flutter pub outdated'

alias fc='flutter clean && flutter pub get'
alias fbr='flutter pub run build_runner build'
alias fbrd='flutter pub run build_runner build --delete-conflicting-outputs'
alias fbrw='flutter pub run build_runner watch --delete-conflicting-outputs'
alias fgen='dart run build_runner build --delete-conflicting-outputs'  # Dart 3+
alias fgenw='dart run build_runner watch --delete-conflicting-outputs'

alias fa='flutter analyze'
alias ft='flutter test'
alias ftc='flutter test --coverage'
alias fdoc='flutter doctor -v'
alias fdev='flutter devices'
alias femu='flutter emulators --launch'

# Build
alias fb-apk='flutter build apk --release'
alias fb-aab='flutter build appbundle --release'
alias fb-ios='flutter build ios --release'
alias fb-web='flutter build web --release'
alias fb-linux='flutter build linux --release'

# Common fix
alias ffix='flutter clean && flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs'

# Create a clean Flutter project
fnew() { flutter create --org com.${2:-$USER} --template=app $1 && cd $1 && flutter pub get; }
fi
