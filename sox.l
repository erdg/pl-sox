# NOTE - depends on 'sox' (and optionally 'lame' for mp3 conversion).

(de sox (Str) (call 'sh "-c" (pack "sox " Str)) )

(de sh (Str) (call 'sh "-c" Str))

(de sox? () (call 'man "sox"))

(de mv (File New) (call 'mv File New) New)
(de rm (File) (call 'rm File))

(de remove-unwanted-files ()
   (mapc rm (filter '((S) (sub? "%" S)) (dir))) )

(de play (File)
   (call 'sh "-c"
      (text "play @1" File)))

(de play-with-effects (File Effects)
   (call 'sh "-c" (text "play @1 @2" File Effects)) )

(de record (File)
   (prog1 File
      (call 'rec "-r" "48000" "-c" "1" File) ) )

(de record-over (Orig New)
   (call 'sh "-c" (text "play -q @1 & rec -c 1 @2" Orig New)) )

(de record-stereo (File)
   (ifn (member File (dir))
      (call 'rec "-r" "48000" "-c" "2" File)
      (prinl "File exists - overwrite it? Press \"T\" to continue")
      (ifn (= (key) "T")
         (nil (prinl "Aborted."))
         (prog1 File (call 'rec "-r" "48000" "-c" "2" File)) ) ) )

(de record-stereo-over (Orig New)
   (call 'sh "-c" (text "play -q @1 & rec -c 2 @2" Orig New)) )

(de mono-mix-down (File)
   (let New (append-file-name File "-mono.wav")
      (call 'sh "-c"
         (text "sox @1 @2 remix 1-2"
            File
            New ) )
      New ) )

# rapid fire piano / vox mono mix
(de quicktrack (File)
   (record-stereo File)
   (and
      (mono-mix-down File)
      (play @) ) )

### TODO ###
#
# Clean up the pollution! Must find a way to manage the growing
# pile of files.
#
###

# NOTE - e.g. "-v 0.6 bass.wav" to adjust track volume in mix
(de new-mix (Name . Tracks)
   (call 'sh "-c"
      (pack "sox -m " (glue " " Tracks) " " Name) ) )

(de remove-beggining-silence (File)
   (let New (append-file-name File "%.wav")
      (call 'sh "-c"
         (text "sox @1 @2 silence 1 0.1 1%" File New) )
      New ) )

# NOTE - include ".whatever" in 'Text'
(de append-file-name (File Text)
   (pack (car (split (chop File) ".")) Text) )

(de remove-ending-silence (File)
   (and File
      (reverse-audio @)
      (remove-beggining-silence @)
      (reverse-audio @) ) )

(de reverse-audio (File)
   (let New (append-file-name File "%.wav")
      (call 'sh "-c"
         (text "sox @1 @2 reverse" File New) )
      New ) )

(de trim-audio-to-seconds (File Secs)
   (let New (append-file-name File "%.wav")
      (call 'sh "-c"
         (text "sox @1 @2 trim 0 @3"
            File
            New
            Secs ) )
      New ) )

(de volume (File Vol)
   (let New (append-file-name File "%.wav")
      (call 'sh "-c"
         (text "sox -v @1 @2 @3"
            Vol
            File
            New ) )
      New ) )

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

(de preloopify (File Measures TimeSig Tempo)
   # make File loopable for the given Measures/Tempo/TimeSig
   (and File
      (remove-beggining-silence @)
      (trim-audio-to-seconds @ (time-calc Measures TimeSig Tempo))
      (remove-pops @)
      (prog1
         (mv @ (append-file-name File "-preloop.wav"))
         (remove-unwanted-files) ) ) )

# TODO - implement using 'splice' instead of 'concatenate'
(de loopify (File Times)
   (let [Orig
            (use @A @B
               (match (append '(@A) (chop "-preloop") '(@B)) (chop File))
               (pack @A @B) )
         New (append-file-name Orig "-loop.wav") ]
      # "sox FILE FILE FILE FILE FILE File-loop.wav"
      (call 'sh "-c"
         (pack "sox " (glue " " (need Times File)) " " New) ) ) )

# silence values need tweaking
(de record-beatz (File)
   (call 'sh "-c"
      (text
         "rec -r 48000 -p silence 1 0.50 0.1% 1 10:00 0.1% | \
            sox -p @1 silence 1 0.50 0.1% 1 2.0 0.1% : \
            newfile : restart"
         File ) ) )

(de record-beatz-over (File New)
   (call 'sh "-c"
      (text
         "play -q @1 & rec -r 48000 -p silence 1 0.50 0.1% 1 10:00 0.1% | \
            sox -p @2 silence 1 0.50 0.1% 1 2.0 0.1% : \
            newfile : restart"
         File New ) ) )

(de lame (File) (call 'lame (pack File ".wav") (pack File ".mp3")))

(de normalize (File)
   (let New (append-file-name File "_normalized.wav")
      (sox
         (text "--norm=-3 @1 @2"
            File
            New ) )
      New ) )

(de remove-noise (File)
   (let New (append-file-name File "%.wav")
      (sox
         (text "@1 -n trim 0 1 noiseprof | sox @1 @2 noisered"
            File
            New ) )
      New ) )

(de remove-pops (File)
   (let New (append-file-name File "%.wav")
      (sox
         (text "@1 @2 fade q 0.04 0 0.04"
            File
            New ) )
      New ) )
