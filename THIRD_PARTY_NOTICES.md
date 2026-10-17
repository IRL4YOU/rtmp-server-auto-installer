# Hinweise zu Fremdkomponenten

Der Installer installiert Nginx und `libnginx-mod-rtmp` aus den Paketquellen des jeweiligen Betriebssystems. Er verteilt deren Binärdateien oder Quellcode nicht selbst. Die Lizenzangaben der installierten Pakete sind auf dem Zielsystem unter `/usr/share/doc/` zu finden.

- Nginx: [offizielles Nginx-Projekt und Lizenz](https://nginx.org/en/docs/faq/license_copyright.html)
- RTMP-Modul: [Originalprojekt](https://github.com/arut/nginx-rtmp-module) und [BSD-2-Clause-Lizenz](https://github.com/arut/nginx-rtmp-module/blob/master/LICENSE)

Die eigene Statistikansicht `downloads/stat-v3.xsl` verarbeitet die vom RTMP-Modul bereitgestellte XML-Struktur. Der Lizenz- und Copyright-Hinweis des Originalprojekts für dessen `stat.xsl` wird vorsorglich auch hier wiedergegeben:

```text
Copyright (c) 2012-2014, Roman Arutyunyan

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
