import mutagen

def rva_from_string(gain, peak):
    rg_gain = float(gain[0].split(' ')[0])
    rg_peak = float(peak[0])
    return mutagen.id3.RVA2(desc=u'track', channel=1, gain=rg_gain, peak=rg_peak)

def rva_to_string(rva):
    rg_gain = rva._raw_gain or "%.2f dB" % rva.gain
    rg_peak = rva._raw_peak or "%.2f dB" % rva.peak
    return (rg_gain, rg_peak)

def rva_to_soundcheck(rva):
    # http://projects.robinbowes.com/flac2mp3/trac/ticket/30#comment:7
    # [-1]: prefixed with a space
    # [0, 1]: volume adjustment in 1/1000 W per dBm
    # [2, 3]: volume adjustment in 1/2500 W per dBm
    # [4, 5]: unsure (identical for same song when volumes differ)
    # [6, 7]: peak (max sample) as absolute value: 0x7FFF for 16-bit samples
    # [8, 9]: same as [4, 5]
    gain2sc = lambda gain, base: u"%08X" % min(round((10 ** (-gain/10)) * base), 65534)

    sc = [
        u"",
        # 1/1000 W per dBm
        gain2sc(rva.gain, 1000),
        gain2sc(rva.gain, 1000),
        # 1/2500 W per dBm
        gain2sc(rva.gain, 2500),
        gain2sc(rva.gain, 2500),
        u"00024CA8",
        u"00024CA8",
        u"00007FFF",
        u"00007FFF",
        u"00024CA8",
        u"00024CA8",
    ]

    return u" ".join(sc)

class GainValue(object):
    MODES = {'track', 'album'}

    def __init__(self, mode=u'track'):
        if mode not in self.MODES:
            raise ValueError("mode must be one of %r" % self.MODES)

        self._mode = unicode(mode)

        self.gain = None
        self.peak = 1.0
        self._raw_gain = None
        self._raw_peak = None

    def __repr__(self):
        return "<GainValue mode=%s gain=%f peak=%f>" % (self._mode, self.gain, self.peak)

    @property
    def mode(self):
        return self._mode

    @mode.setter
    def mode(self, value):
        if value not in self.MODES:
            raise ValueError("mode must be one of %r" % self.MODES)

        self._mode = unicode(value)

    @classmethod
    def from_rva2(self, mode, frame):
        gv = self(mode)
        gv.gain = frame.gain
        gv.peak = frame.peak
        return gv

    @classmethod
    def from_string(self, mode, gain, peak):
        rg_gain = float(gain[0].split(' ')[0])
        rg_peak = float(peak[0].split(' ')[0])

        gv = self(mode)
        gv._raw_gain = gain
        gv._raw_peak = peak
        gv.gain = rg_gain
        gv.peak = rg_peak
        return gv

    def to_string(self):
        rg_gain = self._raw_gain or "%.2f dB" % self.gain
        rg_peak = self._raw_peak or "%.2f dB" % self.peak
        return (rg_gain, rg_peak)

    def to_rva2(self):
        return mutagen.id3.RVA2(desc=self._mode, channel=1, gain=self.gain, peak=self.peak)

    def to_soundcheck(self):
        return rva_to_soundcheck(self)

    @classmethod
    def import_tag(self, tag, mode):
        if mode not in self.MODES:
            raise ValueError("mode must be one of %r" % self.MODES)

        if (u'RVA2:%s' % mode) in tag:
            # ID3v2.4 RVA2
            #print "Found ID3v2.4 RVA2 frame"
            return self.from_rva2(mode, tag[u'RVA2:%s' % mode])
        elif (u'TXXX:replaygain_%s_gain' % mode) in tag:
            # ID3v2 foobar2000
            #print "Found ID3v2 foobar2000 tag"
            return self.from_string(mode,
                                    tag[u'TXXX:replaygain_%s_gain' % mode],
                                    tag[u'TXXX:replaygain_%s_peak' % mode])
        elif ('----:com.apple.iTunes:replaygain_%s_gain' % mode) in tag:
            # MP4 foobar2000
            #print "Found MP4 foobar2000 tag"
            return self.from_string(mode,
                                    tag['----:com.apple.iTunes:replaygain_%s_gain' % mode],
                                    tag['----:com.apple.iTunes:replaygain_%s_peak' % mode])
        elif ('replaygain_%s_gain' % mode) in tag:
            # FLAC
            #print "Found FLAC tag"
            return self.from_string(mode,
                                    tag['replaygain_%s_gain' % mode],
                                    tag['replaygain_%s_peak' % mode])
        else:
            return None

    def export_id3(self, tag):
        tag[u'RVA2:%s' % self._mode] = self.to_rva2()

        rg_gain, rg_peak = self.to_string()
        tx_gain = mutagen.id3.TXXX(desc=u'replaygain_%s_gain' % self._mode,
                                   encoding=1, text=[rg_gain])
        tx_peak = mutagen.id3.TXXX(desc=u'replaygain_%s_peak' % self._mode,
                                   encoding=1, text=[rg_peak])
        tag[u'TXXX:'+tx_gain.desc] = tx_gain
        tag[u'TXXX:'+tx_peak.desc] = tx_peak

        if self._mode == 'track':
            sc_raw = self.to_soundcheck()
            sc_norm = mutagen.id3.COMM(desc=u'iTunNORM', lang='eng',
                                       encoding=0, text=[sc_raw])
            #tag[u"COMM:%s:'%s'" % (sc_norm.desc, sc_norm.lang)] = sc_norm
            del tag[u"COMM:%s:'%s'" % (sc_norm.desc, sc_norm.lang)]

    def export_mp4(self, tag):
        #print "Adding MP4 foobar2000 tag"
        rg_gain, rg_peak = self.to_string()
        tag['----:com.apple.iTunes:replaygain_%s_gain' % self._mode] = rg_gain
        tag['----:com.apple.iTunes:replaygain_%s_peak' % self._mode] = rg_peak

    def export_flac(self, tag):
        #print "Adding FLAC tag"
        rg_gain, rg_peak = self.to_string()
        tag['replaygain_%s_gain' % self._mode] = rg_gain
        tag['replaygain_%s_peak' % self._mode] = rg_peak

