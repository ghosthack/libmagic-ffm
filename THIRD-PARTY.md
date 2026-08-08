# Third-party notices

The classifier jars contain the shared library and compiled signature database
from **file/libmagic 5.48**. The Windows build applies the small, published
`file-5.48-mingw-time_t.patch` to safely convert MinGW's `timespec.tv_sec` to
its differently sized `time_t`; the macOS and Linux builds use unmodified
source. file/libmagic is licensed under the BSD 2-Clause license. Its license
text is included in every native jar as `COPYING.libmagic`, and the exact
source URL, patch, and build options are recorded in `BUILD-INFO.txt`.

The Windows classifier also includes the MSYS2 regex/runtime closure required
by libmagic: **libsystre** (BSD-2-Clause), **libtre** (BSD), and the
**gettext-runtime/libintl** and **libiconv** DLLs (LGPL-2.1-or-later). Their
license texts and versions are included in the classifier jar. All are loaded
as user-replaceable shared libraries.

The Java binding and wrapper code is MIT-licensed; see `LICENSE`.
