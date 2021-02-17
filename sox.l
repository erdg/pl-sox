# NOTE - depends on 'sox' (and optionally 'lame' for mp3 conversion).


# help
(de sox? () (call 'man "sox"))

# general
(de sox (@Str . Rest) (macro (sh (pack "sox " @Str) ^ Rest)))


### play / record
##
#

(de play (File) (sh "play @1" File))

(de play-with-effects (File Effects)
   (sh "play @1 @2" File Effects) )

(de record-safely (@Recorder)
   # read macro - captures symbol 'File. prevents accidental overwrites and adds
   # some 'prinl's to make the output easier to parse.
   (macro
      '(ifn (member File (dir))
         (prog1 File @Recorder (prinl))
         (prinl)
         (prinl "WARNING - File \"" File "\" exists. Press \"T\" to overwrite it.")
         (ifn (= (key) "T")
            (nil (prinl "Aborted."))
            (prog1 File @Recorder (prinl)) ) ) ) )

(de record (File)
   `(record-safely '(_record File)) )

(de _record (File)
   (sh "rec -c 1 @1" File) )

(de record-stereo (File)
   `(record-safely '(_record-stereo File)) )

(de _record-stereo (File)
   (sh "rec -c 2 @1" File) )

(de record-over (File Over)
   `(record-safely '(_record-over File Over)) )

(de _record-over (File Over)
   (sh "play -q @1 & rec -c 1 @2" Over File) )

(de record-over-loop (File Over)
   `(record-safely '(_record-over-loop File Over)) )

(de _record-over-loop (File Over)
   (sh "play -q @1 repeat - & rec -c 1 @2" Over File) )

(de record-stereo-over (File Over)
   `(record-safely '(_record-stereo-over File Over)) )

(de _record-stereo-over (File Over)
   (sh "play -q @1 & rec -c 2 @2" Over File) )

# silence values need tweaking
(de record-multi (File)
   (call 'sh "-c"
      (text
         "rec -r 48000 -p silence 1 0.50 0.1% 1 10:00 0.1% | \
            sox -p @1 silence 1 0.50 0.1% 1 2.0 0.1% : \
            newfile : restart"
         File ) ) )

(de record-multi% (File)
   (sh
      "rec -r 48000 -p silence 1 0.50 0.1% 1 10:00 0.1% | \
      sox -p @1 silence 1 0.50 0.1% 1 2.0 0.1% : \
      newfile : restart"
      File ) )

(de record-multi-over (File New)
   (call 'sh "-c"
      (text
         "play -q @1 & rec -r 48000 -p silence 1 0.50 0.1% 1 10:00 0.1% | \
            sox -p @2 silence 1 0.50 0.1% 1 2.0 0.1% : \
            newfile : restart"
         File New ) ) )


### mixes
##
#

# NOTE - e.g. "-v 0.6 bass.wav" to adjust track volume in mix
(de new-mix (Name . Tracks)
   (sox "-m @1 @2" (glue " " Tracks) Name)
   Name )

(de normalize (File)
   (let New (append-file-name File "-normalized.wav")
      (sox "--norm=-3 @1 @2" File New)
      New ) )

# stereo -> mono
(de mono-mix-down (File)
   (let New (append-file-name File "-mono.wav")
      (sox "@1 @2 remix 1-2" File New)
      New ) )

# rapid fire piano / vox mono mix
#
# NOTE - this isn't really needed, just use 'record' with both channels
# activated.
(de quicktrack (File)
   (record-stereo File)
   (and
      (mono-mix-down File)
      (play @) ) )

# mp3 conversion
(de lame (File) (call 'lame (pack File ".wav") (pack File ".mp3")))


##### editing fns
###
#

(de remove-beggining-silence (File)
   (let New (append-file-name File "%.wav")
      (sox "@1 @2 silence 1 0.1 0.4%"
      # (sox "@1 @2 silence 1 5 2%"
         File
         New )
      New ) )

(de remove-ending-silence (File)
   (and File
      (reverse-audio @)
      (remove-beggining-silence @)
      (reverse-audio @) ) )

(de reverse-audio (File)
   (let New (append-file-name File "%.wav")
      (sox "@1 @2 reverse"
         File
         New )
      New ) )

(de trim-audio-to-seconds (File Secs)
   (let New (append-file-name File "%.wav")
      (sox "@1 @2 trim 0 @3"
         File
         New
         Secs )
      New ) )

(de volume (File Vol)
   (let New (append-file-name File "%.wav")
      (sox "-v @1 @2 @3" Vol File New)
      New ) )

(de remove-noise (File)
   (let New (append-file-name File "%.wav")
      (sox "@1 -n trim 0 1 noiseprof | sox @1 @2 noisered"
         File
         New)
      New ) )

(de remove-pops (File)
   (let New (append-file-name File "%.wav")
      (sox "@1 @2 fade q 0.04 0 0.04"
         File
         New )
      New ) )

(de remove-grain-pops (File)
   (let New (append-file-name File "%.wav")
      (sox "@1 @2 fade q 0.001 0 0.001"
         File
         New )
      New ) )

(de fade-audio (File FadeOpts)
   (let New (append-file-name File "%.wav")
      (sox "@1 @2 fade @3"
         File
         New
         FadeOpts )
      New ) )

(de pad-audio (File PadOpts)
   (let New (append-file-name File "%.wav")
      (sox "@1 @2 pad @3"
         File
         New
         PadOpts )
      New ) )

##### musical time conversions
###
#

(scl 3)

# time-calc - convert musical time to (milli)seconds
#
#  (time-calc 2 "4/4" 60) -> "8.000"
#  (time-calc 2 "7/8" 60) -> "7.500"
#  (time-calc 4 "4/4" 88) -> "10.912" (four measures of 4/4 at 88bpm is 10.912 seconds)
#
(de time-calc (Measures TimeSig Tempo)
   (default TimeSig "4/4")
   (let [C (split (chop TimeSig) "/")  # eg.  "7/8"
         N (any (pack (car C)))        # N <-- 7
         D (any (pack (cdr C))) ]      # D <---- 8
      (format
         (*/
            (* Measures
               N
               (*/ 60 1.0 Tempo) )
            1.0
            (case D
               (32 8.0)
               (16 4.0)
               (8  2.0)
               (4  1.0) ) )
         *Scl ) ) )

# first draft - basic time sigs only ("3/4", "4/4", etc.)
(de time-calc% (Measures TimeSig Tempo)
   (default TimeSig "4/4")
   (format
      (* Measures
         (any (caar (split (chop TimeSig) "/")))
         (*/ 60 1.0 Tempo) )
      *Scl ) )

# create more complex time structures
#
#  (time-calc-multi 160 (2 "7/8") (1 "4/4") (1 "6/8"))
#
(de time-calc-multi (Tempo . Lst)
   (format
      (apply +
         (mapcar '((L) (any (time-calc (car L) (cadr L) Tempo)))
            Lst ) )
      *Scl ) )

(de bpm->seconds/beat (Bpm)
   (format (*/ 60 1.0 Bpm) *Scl) )

(de bpm->ms/beat (Bpm)
   (any (bpm->seconds/beat Bpm)) )


######### looping
#####
#

# make File loopable for the given Measures/Tempo/TimeSig
(de preloopify (File Measures TimeSig Tempo)
   (and File
      (remove-beggining-silence @)
      (trim-audio-to-seconds @ (time-calc Measures TimeSig Tempo))
      (remove-pops @)
      (prog1
         (mv @ (append-file-name File "-preloop.wav"))
         (remove-unwanted-files) ) ) )

# simple audio file concatination
(de loopify% (File Times)
   # "sox FILE FILE FILE FILE FILE File-loop.wav"
   (let [Orig
            (use @A @B
               (if (match (append '(@A) (chop "-preloop") '(@B)) (chop File))
                  (pack @A @B)
                  File ) )
         New (append-file-name Orig "-loop.wav") ]
      (sox "@1 @2"
         (glue " " (need Times File))
         New )
      New ) )

(de loopify (New N File)
   # "sox FILE FILE FILE FILE FILE NEW"
   (sox "@1 @2"
      (glue " " (need N File))
      New )
   New )

### custom metronomes

# variation of 'preloopify'
(de new-click (File Tempo)
   (and File
      (remove-beggining-silence @)
      (trim-audio-to-seconds @ (time-calc 1 "1/4" Tempo))
      (remove-pops @)
      (prog1
         (mv @ (append-file-name File (pack "_" Tempo "bpm.wav")))
         (remove-unwanted-files) ) ) )

# another variation of 'preloopify'
(de samplify (New File Duration Tempo)
   (and File
      (remove-beggining-silence @)
      (trim-audio-to-seconds @ (time-calc 1 (pack "1/" Duration) Tempo))
      (remove-pops @)
      (prog1
         (mv @ New)
         (remove-unwanted-files) ) ) )

# newb granular synthesis
(de new-grain (New From Duration)
   (and From
      (remove-beggining-silence @)
      (trim-audio-to-seconds @ Duration)
      (prog1
         (mv @ New)
         (remove-unwanted-files) ) ) )

# bulk grains
(de chop-audio (From New Duration)
   (sox "@1 @2 trim 0 @3 : newfile : restart"
      From
      New
      Duration ) )

(de chop-audio-to-dir (From New Duration)
   (call 'mkdir New)
   (sox "@1 @2 trim 0 @3 : newfile : restart"
      From
      (pack New "_.wav")
      Duration )
   (for Grain (filter '((X) (pre? (pack New "_") X)) (dir))
      (mv Grain New) )
   (chdir New
      (for File (dir)
         (and
            (remove-grain-pops File) # file%.wav
            (mv @ File) ) )  # rename to original
      (remove-unwanted-files) ) )

# reverse all audio files in directory
(de reverse-all-audio-in-dir (Dir)
   (chdir Dir
      (for File (dir)
        (and
           (reverse-audio File)
           (mv @ File) ) )
      (remove-unwanted-files) ) )

# mess with envelopes
(de apply-random-fades-to-cloud (Dir)
   (chdir Dir
      (for File (dir)
         (and
            (fade-audio File
               (pack "t 0.0" (rand 4 20)) )
            (mv @ File) ) )
      (remove-unwanted-files) ) )

(de apply-random-silence-to-cloud (Dir)
   (chdir Dir
      (for File (dir)
         (and
            (pad-audio File
               (pack "0.0" (rand 4 20)) )
            (mv @ File) ) )
      (remove-unwanted-files) ) )

# there seems to be a pattern here
# implicit "cloud" (directory) name as first arg
(de define-cloud-fn Lst
   (let [(@Nm Args . Fn) Lst]
      (macro
         (de @Nm (Dir ^ Args)
            (chdir Dir
               (for File (dir)   # 'File' is captured for use
                  (and
                     ^ Fn
                     (mv @ File) ) )
               (remove-unwanted-files) ) ) ) ) )

(define-cloud-fn apply-20ms-linear-fade-in ()
   (fade-audio File "t 0.02") )  # 'File' is used in definition

(define-cloud-fn apply-fade-to-cloud (FadeOpts) (fade-audio File FadeOpts))

# render track from cloud directory
(de render-from-cloud (New Cloud . Gen)
   (chdir Cloud
      (macro (sox "@1 @2" (glue " " ^ Gen) New))
      (mv New "..") ) )

# render track of length 'Samples' from multiple cloud directories
# (random-render-from-clouds "new-track.wav" (duration-as-samples "file.wav") "cloud1" "cloud2" "cloud3")
(de random-render-from-clouds (Name Samples . Clouds)
   (sox "@1 @2"
      (glue " "
         (make
            (let Cnt 0
               (loop
                  (T (<= Samples Cnt) (made))
                  (chdir (choose Clouds)
                     (let [File (choose (dir))
                           Smpls (duration-as-samples File)]
                        (link (pack (pwd) "/" File))
                        (inc 'Cnt Smpls) ) ) ) ) ) )
      Name ) )

(de choose (Lst)
   (car (nth Lst (rand 1 (length Lst)))) )

(de duration-as-samples (File)
   (and
      (in (list 'soxi File)
         (make
            (until (eof)
               (when (pre? "D" (line))
                  (link @) ) ) ) )
      (++ @)
      (chop @)
      (stem @ "=")
      (clip @)
      (pack @)
      (split (chop @) " ")
      (any (pack (car @))) ) )

### utils
##
#

# abbrevation for a common pattern in this code
(de sh (@Str . Rest)
   (macro
      (call 'sh "-c"
         (text @Str
            ^ Rest ) ) ) )

(de rm (File)    (call 'rm File))
(de mv (From To) (call 'mv From To) To)

# sox operations create new files. sometimes three or more different sox calls
# are made in a single lisp function. this creates a lot of "transient files" -
# files created during the process, but no longer desirable. these files are
# marked with '%'s and can be removed with the  following function.
(de remove-unwanted-files ()
   (mapc rm (filter '((S) (sub? "%" S)) (dir))) )

# NOTE - include file extension (e.g. ".wav") in 'Text'
(de append-file-name (File Text)
   (pack (car (split (chop File) ".")) Text) )
