# Third-party notices

The classifier jars contain the shared library and compiled signature database
from **file/libmagic 5.48**. The Windows build applies the small, published
`file-5.48-mingw-time_t.patch` to safely convert MinGW's `timespec.tv_sec` to
its differently sized `time_t`; the macOS and Linux builds use unmodified
source. file/libmagic is licensed under the BSD 2-Clause license. Its license
text is included in every native jar as `COPYING.libmagic`, and the exact
source URL, patch, and build options are recorded in `BUILD-INFO.txt`.

The Java binding and wrapper code is MIT-licensed; see `LICENSE`.
