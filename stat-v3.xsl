<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>
  <xsl:template name="duration">
    <xsl:param name="ms"/><xsl:choose><xsl:when test="not(number($ms) = number($ms))">–</xsl:when><xsl:otherwise>
      <xsl:variable name="s" select="floor(number($ms) div 1000)"/><xsl:variable name="d" select="floor($s div 86400)"/>
      <xsl:variable name="h" select="floor(($s mod 86400) div 3600)"/><xsl:variable name="m" select="floor(($s mod 3600) div 60)"/><xsl:variable name="r" select="$s mod 60"/>
      <xsl:if test="$d &gt; 0"><xsl:value-of select="$d"/>d </xsl:if><xsl:value-of select="format-number($h,'00')"/>:<xsl:value-of select="format-number($m,'00')"/>:<xsl:value-of select="format-number($r,'00')"/>
    </xsl:otherwise></xsl:choose>
  </xsl:template>
  <xsl:template name="bytes">
    <xsl:param name="n"/><xsl:choose>
      <xsl:when test="not(number($n) = number($n))">–</xsl:when>
      <xsl:when test="$n &gt;= 1099511627776"><xsl:value-of select="format-number($n div 1099511627776,'0.00')"/> TiB</xsl:when>
      <xsl:when test="$n &gt;= 1073741824"><xsl:value-of select="format-number($n div 1073741824,'0.00')"/> GiB</xsl:when>
      <xsl:when test="$n &gt;= 1048576"><xsl:value-of select="format-number($n div 1048576,'0.00')"/> MiB</xsl:when>
      <xsl:when test="$n &gt;= 1024"><xsl:value-of select="format-number($n div 1024,'0.00')"/> KiB</xsl:when>
      <xsl:otherwise><xsl:value-of select="format-number($n,'0')"/> B</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="bandwidth">
    <xsl:param name="n"/><xsl:choose>
      <xsl:when test="not(number($n) = number($n))">–</xsl:when>
      <xsl:when test="$n &gt;= 1000000000"><xsl:value-of select="format-number($n div 1000000000,'0.00')"/> Gbit/s</xsl:when>
      <xsl:when test="$n &gt;= 1000000"><xsl:value-of select="format-number($n div 1000000,'0.00')"/> Mbit/s</xsl:when>
      <xsl:when test="$n &gt;= 1000"><xsl:value-of select="format-number($n div 1000,'0.00')"/> kbit/s</xsl:when>
      <xsl:otherwise><xsl:value-of select="format-number($n,'0')"/> bit/s</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="value-or-dash"><xsl:param name="value"/><xsl:choose><xsl:when test="string-length(normalize-space($value))"><xsl:value-of select="$value"/></xsl:when><xsl:otherwise>–</xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template match="/">
    <xsl:variable name="root" select="/*"/><xsl:variable name="streams" select="$root//application/live/stream"/>
    <html lang="de"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/><meta http-equiv="refresh" content="10"/><title>RTMP Server Status</title>
      <style>
        :root{color-scheme:light;--blue:#245a8d;--line:#c9d3dc;--soft:#eef3f7;--text:#263746;--muted:#617180}*{box-sizing:border-box}
        body{margin:0;padding:24px;background:#f4f6f8;color:var(--text);font:14px/1.45 Arial,Helvetica,sans-serif}main{max-width:1500px;margin:auto}
        h1{margin:0;padding:15px 18px;background:var(--blue);color:white;font-size:22px;font-weight:600}h2{margin:28px 0 8px;font-size:18px;color:#173f65}
        .panel{overflow:hidden;border:1px solid var(--line);background:white;box-shadow:0 1px 3px rgba(0,0,0,.06)}.summary{display:grid;grid-template-columns:repeat(5,minmax(150px,1fr))}
        .metric{padding:14px 16px;border-right:1px solid var(--line);border-bottom:1px solid var(--line)}.metric span{display:block;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:4px;font-size:17px}
        .table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;white-space:nowrap}th{padding:9px 10px;background:var(--soft);border:1px solid var(--line);color:#29475f;text-align:left;font-size:12px}td{padding:9px 10px;border:1px solid var(--line);vertical-align:top}tbody tr:nth-child(even){background:#fafbfd}.live{color:#16733c;font-weight:bold}.empty{padding:22px;color:var(--muted);text-align:center}footer{margin-top:12px;color:var(--muted);font-size:12px}footer a{display:inline-block;margin-top:5px;color:#245a8d;font-weight:700;text-decoration:underline;text-underline-offset:2px}@media(max-width:900px){body{padding:10px}.summary{grid-template-columns:repeat(2,1fr)}}
      </style></head><body><main><h1>RTMP Server Status</h1><div class="panel summary">
        <div class="metric"><span>Server-Uptime</span><strong><xsl:call-template name="duration"><xsl:with-param name="ms" select="$root/uptime * 1000"/></xsl:call-template></strong></div>
        <div class="metric"><span>Bandbreite eingehend</span><strong><xsl:call-template name="bandwidth"><xsl:with-param name="n" select="$root/bw_in"/></xsl:call-template></strong></div>
        <div class="metric"><span>Bandbreite ausgehend</span><strong><xsl:call-template name="bandwidth"><xsl:with-param name="n" select="$root/bw_out"/></xsl:call-template></strong></div>
        <div class="metric"><span>Bytes In</span><strong><xsl:call-template name="bytes"><xsl:with-param name="n" select="$root/bytes_in"/></xsl:call-template></strong></div>
        <div class="metric"><span>Bytes Out</span><strong><xsl:call-template name="bytes"><xsl:with-param name="n" select="$root/bytes_out"/></xsl:call-template></strong></div>
        <div class="metric"><span>Aktive Streams</span><strong><xsl:value-of select="count($streams)"/></strong></div>
      </div><h2>Aktive Streams</h2><div class="panel table-wrap"><table><thead><tr><th>Application</th><th>Streamname</th><th>Publisher / Clients</th><th>Video</th><th>Auflösung</th><th>FPS</th><th>Video-Bandbreite</th><th>Audio</th><th>Sample-Rate / Kanäle</th><th>Laufzeit</th></tr></thead><tbody>
        <xsl:for-each select="$streams"><tr>
          <td><xsl:call-template name="value-or-dash"><xsl:with-param name="value" select="ancestor::application[1]/name"/></xsl:call-template></td>
          <td class="live"><xsl:call-template name="value-or-dash"><xsl:with-param name="value" select="name"/></xsl:call-template></td>
          <td><xsl:value-of select="count(client[publishing])"/> / <xsl:choose><xsl:when test="nclients"><xsl:value-of select="nclients"/></xsl:when><xsl:otherwise><xsl:value-of select="count(client)"/></xsl:otherwise></xsl:choose></td>
          <td><xsl:call-template name="value-or-dash"><xsl:with-param name="value" select="meta/video/codec"/></xsl:call-template></td>
          <td><xsl:choose><xsl:when test="meta/video/width and meta/video/height"><xsl:value-of select="meta/video/width"/> × <xsl:value-of select="meta/video/height"/></xsl:when><xsl:otherwise>–</xsl:otherwise></xsl:choose></td>
          <td><xsl:call-template name="value-or-dash"><xsl:with-param name="value" select="meta/video/frame_rate"/></xsl:call-template></td>
          <td><xsl:call-template name="bandwidth"><xsl:with-param name="n" select="bw_video"/></xsl:call-template></td>
          <td><xsl:call-template name="value-or-dash"><xsl:with-param name="value" select="meta/audio/codec"/></xsl:call-template></td>
          <td><xsl:choose><xsl:when test="meta/audio/sample_rate or meta/audio/channels"><xsl:call-template name="value-or-dash"><xsl:with-param name="value" select="meta/audio/sample_rate"/></xsl:call-template> Hz / <xsl:call-template name="value-or-dash"><xsl:with-param name="value" select="meta/audio/channels"/></xsl:call-template></xsl:when><xsl:otherwise>–</xsl:otherwise></xsl:choose></td>
          <td><xsl:call-template name="duration"><xsl:with-param name="ms" select="time"/></xsl:call-template></td>
        </tr></xsl:for-each>
        <xsl:if test="not($streams)"><tr><td class="empty" colspan="10">Zurzeit sind keine aktiven Streams vorhanden.</td></tr></xsl:if>
      </tbody></table></div><footer>Automatische Aktualisierung alle 10 Sekunden<br/><a href="https://irl4you.de/">Viel Spaß beim Streamen mit deinem RTMP-Server! – IRL4YOU.de</a></footer>
    </main></body></html>
  </xsl:template>
</xsl:stylesheet>
