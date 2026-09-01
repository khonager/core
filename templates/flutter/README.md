# Flutter template

These files are references to copy and adapt, not a project generator.

- `.github/workflows/android.yml` builds Android artifacts and shows the
  separation between untrusted builds and signed releases.
- `scripts/release.sh` creates a guarded stable version tag.

Replace every `APP_NAME` placeholder, choose a pinned Flutter version, document
all build defines, and adapt artifact paths if the app uses flavors. Production
publishing requires application-specific signing and license decisions.

