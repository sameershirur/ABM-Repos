@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
; ------------------------------------------------------------
; Construction Site Worker Safety — ABM (NetLogo)
; ------------------------------------------------------------
extensions []

breed [ workers worker ]
breed [ supervisors supervisor ]
breed [ vehicles vehicle ]

patches-own [
  base-hazard
  dynamic-hazard
  hazard-level
]

workers-own [
  ppe?
  safety-attitude
  risk-tolerance
  training
  fatigue
  task-target
  off-duty?
  off-until
]

supervisors-own [
  inspection-power
]

vehicles-own [
  speed
  vehicle-radius
]

globals [
  NUM-WORKERS
  NUM-SUPERVISORS
  NUM-VEHICLES
  HAZARD-HOTSPOTS
  HAZARD-RADIUS
  WALK-SPEED
  PPE-BASE-ADHERENCE
  PPE-PROTECTION
  COWORKER-SUPPORT
  SUPERVISION-RADIUS
  TRAINING-INTERVAL
  TRAINING-BOOST
  TRAINING-EFFECT
  FATIGUE-RISE
  FATIGUE-RECOVERY
  BREAK-INTERVAL
  RISK-SCALE
  INCIDENT-SEVERITY-RATE
  INCIDENT-DOWNTIME
  SEED

  incidents
  near-misses
  total-exposures
  running-risk-sum
  last-training-tick
]

to setup
  clear-all
  set NUM-WORKERS         (ifelse-value is-number? NUM-WORKERS [NUM-WORKERS] [80])
  set NUM-SUPERVISORS     (ifelse-value is-number? NUM-SUPERVISORS [NUM-SUPERVISORS] [2])
  set NUM-VEHICLES        (ifelse-value is-number? NUM-VEHICLES [NUM-VEHICLES] [3])
  set HAZARD-HOTSPOTS     (ifelse-value is-number? HAZARD-HOTSPOTS [HAZARD-HOTSPOTS] [4])
  set HAZARD-RADIUS       (ifelse-value is-number? HAZARD-RADIUS [HAZARD-RADIUS] [6])
  set WALK-SPEED          (ifelse-value is-number? WALK-SPEED [WALK-SPEED] [0.6])
  set PPE-BASE-ADHERENCE  (ifelse-value is-number? PPE-BASE-ADHERENCE [PPE-BASE-ADHERENCE] [0.65])
  set PPE-PROTECTION      (ifelse-value is-number? PPE-PROTECTION [PPE-PROTECTION] [0.55])
  set COWORKER-SUPPORT    (ifelse-value is-number? COWORKER-SUPPORT [COWORKER-SUPPORT] [0.35])
  set SUPERVISION-RADIUS  (ifelse-value is-number? SUPERVISION-RADIUS [SUPERVISION-RADIUS] [4])
  set TRAINING-INTERVAL   (ifelse-value is-number? TRAINING-INTERVAL [TRAINING-INTERVAL] [300])
  set TRAINING-BOOST      (ifelse-value is-number? TRAINING-BOOST [TRAINING-BOOST] [0.15])
  set TRAINING-EFFECT     (ifelse-value is-number? TRAINING-EFFECT [TRAINING-EFFECT] [0.5])
  set FATIGUE-RISE        (ifelse-value is-number? FATIGUE-RISE [FATIGUE-RISE] [0.002])
  set FATIGUE-RECOVERY    (ifelse-value is-number? FATIGUE-RECOVERY [FATIGUE-RECOVERY] [0.12])
  set BREAK-INTERVAL      (ifelse-value is-number? BREAK-INTERVAL [BREAK-INTERVAL] [180])
  set RISK-SCALE          (ifelse-value is-number? RISK-SCALE [RISK-SCALE] [0.25])
  set INCIDENT-SEVERITY-RATE (ifelse-value is-number? INCIDENT-SEVERITY-RATE [INCIDENT-SEVERITY-RATE] [0.25])
  set INCIDENT-DOWNTIME   (ifelse-value is-number? INCIDENT-DOWNTIME [INCIDENT-DOWNTIME] [60])
  set SEED                (ifelse-value is-number? SEED [SEED] [random 100000])
  random-seed SEED

  set incidents 0
  set near-misses 0
  set total-exposures 0
  set running-risk-sum 0
  set last-training-tick 0

  setup-patches
  setup-workers
  setup-supervisors
  setup-vehicles
  reset-ticks
end

to setup-patches
  ask patches [
    set base-hazard 0
    set dynamic-hazard 0
    set hazard-level 0
    set pcolor gray + 1
  ]
  repeat HAZARD-HOTSPOTS [
    let center one-of patches
    ask patches with [ distance center < HAZARD-RADIUS ] [
      set base-hazard max list base-hazard ( (HAZARD-RADIUS - distance center) / HAZARD-RADIUS * (0.3 + random-float 0.5) )
      set base-hazard min list base-hazard 1
    ]
  ]
  recolor-hazards
end

to setup-workers
  create-workers NUM-WORKERS [
    setxy random-xcor random-ycor
    set shape "person"
    set size 1.1
    set color white
    set ppe? (random-float 1 < PPE-BASE-ADHERENCE)
    set safety-attitude random-float 1
    set risk-tolerance random-float 1
    set training random-float 0.4
    set fatigue 0
    set task-target one-of patches
    set off-duty? false
    set off-until -1
  ]
end

to setup-supervisors
  create-supervisors NUM-SUPERVISORS [
    setxy random-xcor random-ycor
    set shape "person police"
    set size 1.2
    set color blue + 2
    set inspection-power (0.5 + random-float 0.5)
  ]
end

to setup-vehicles
  create-vehicles NUM-VEHICLES [
    setxy random-xcor random-ycor
    set heading random 360
    set shape "truck"
    set size 1.4
    set color orange + 2
    set speed (0.4 + random-float 0.5)
    set vehicle-radius 3 + random 2
  ]
end

to go
  if not any? workers [ stop ]
  update-dynamic-hazards
  worker-behavior
  supervisor-patrols
  process-training
  process-breaks
  recolor-hazards
  update-metrics
  tick
end

to update-dynamic-hazards
  ask patches [ set dynamic-hazard 0 ]
  ask vehicles [
    if not can-move? speed [ set heading heading + 180 ]
    fd speed
    rt random 11 - 5
    ask patches in-radius vehicle-radius [
      set dynamic-hazard min list 1 (dynamic-hazard + 0.25)
    ]
  ]
  ask patches [
    set hazard-level min list 1 (base-hazard + dynamic-hazard)
  ]
end

to recolor-hazards
  ask patches [
    if hazard-level > 0 [ set pcolor scale-color red hazard-level 0 1 ]
    if hazard-level = 0 [ set pcolor gray + 1 ]
  ]
end

to worker-behavior
  ask workers [
    if off-duty? [
      if ticks >= off-until [
        set off-duty? false
        set color white
      ]
      stop
    ]
    if distance task-target < 1 [ set task-target one-of patches ]
    facexy [pxcor] of task-target [pycor] of task-target
    fd WALK-SPEED

    if not ppe? [
      if any? other workers in-radius 2 with [ ppe? ] [
        if random-float 1 < COWORKER-SUPPORT [ set ppe? true ]
      ]
    ]

    let nearby-super count supervisors in-radius SUPERVISION-RADIUS
    if nearby-super > 0 and not ppe? [
      if random-float 1 < (0.2 + 0.15 * nearby-super) [ set ppe? true ]
    ]

    set fatigue min (fatigue + FATIGUE-RISE) 1

    let hl [hazard-level] of patch-here
    if hl > 0 [
      set total-exposures total-exposures + 1
      let risk (exposure-risk self hl)
      set running-risk-sum running-risk-sum + risk

      if random-float 1 < risk [
        if random-float 1 < INCIDENT-SEVERITY-RATE [
          set incidents incidents + 1
          set off-duty? true
          set off-until (ticks + INCIDENT-DOWNTIME)
          set color red + 2
        ] [
          set near-misses near-misses + 1
          set ppe? true
          set safety-attitude min (safety-attitude + 0.05) 1
        ]
      ]
    ]
  ]
end

to-report exposure-risk [ w hl ]
  let ppe-mult (ifelse-value [ppe?] of w [ 1 - PPE-PROTECTION ] [ 1 ])
  let training-mult (1 - (TRAINING-EFFECT * [training] of w))
  let fatigue-mult (1 + 0.8 * [fatigue] of w)
  let attitude-mult (1 + 0.4 * (1 - [safety-attitude] of w))
  let risk-tol-mult (1 + 0.5 * [risk-tolerance] of w)
  let sup-count count supervisors in-radius SUPERVISION-RADIUS
  let supervision-mult (1 - min (sup-count * 0.15) 0.6)
  let r hl * ppe-mult * training-mult * fatigue-mult * attitude-mult * risk-tol-mult * supervision-mult
  set r r * RISK-SCALE
  report min list r 0.9
end

to supervisor-patrols
  ask supervisors [
    if not can-move? 0.6 [ set heading heading + 180 ]
    rt random 11 - 5
    fd 0.6
    if random-float 1 < 0.3 [
      ask workers in-radius SUPERVISION-RADIUS with [ not ppe? ] [
        if random-float 1 < [inspection-power] of myself [ set ppe? true ]
      ]
    ]
  ]
end

to process-training
  if ticks - last-training-tick >= TRAINING-INTERVAL [
    set last-training-tick ticks
    ask workers with [ not off-duty? ] [
      set training min (training + TRAINING-BOOST) 1
      set safety-attitude min (safety-attitude + 0.05) 1
    ]
  ]
end

to process-breaks
  if BREAK-INTERVAL > 0 and ticks mod BREAK-INTERVAL = 0 [
    ask workers with [ not off-duty? ] [
      set fatigue max (fatigue - FATIGUE-RECOVERY) 0
    ]
  ]
end

to update-metrics
  plot-safe "Incidents vs Near-Misses" (list incidents near-misses)
  plot-safe "PPE Compliance (%)" (ppe-compliance * 100)
  plot-safe "Avg Exposure Risk" avg-exposure-risk
end

to plot-safe [plot-name value]
  carefully [
    set-current-plot plot-name
    if is-list? value [
      set-plot-x-range 0 3
      clear-plot
      set-current-plot-pen "Incidents"
      plotxy 1 item 0 value
      set-current-plot-pen "Near-misses"
      plotxy 2 item 1 value
    ] [
      plot value
    ]
  ] [
    ; no-op
  ]
end

to-report ppe-compliance
  ifelse any? workers
  [ report count workers with [ ppe? and not off-duty? ] / count workers with [ not off-duty? ] ]
  [ report 0 ]
end

to-report avg-exposure-risk
  ifelse total-exposures > 0
  [ report running-risk-sum / total-exposures ]
  [ report 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
270
10
880
610
-1
-1
11.0
1
10
1
1
1
0
0
0
1
-25
25
-25
25
1
ticks
30.0

BUTTON
10
10
120
40
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
140
10
250
40
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
60
250
93
NUM-WORKERS
NUM-WORKERS
20
200
80
1
1
NIL
HORIZONTAL

SLIDER
10
95
250
128
NUM-SUPERVISORS
NUM-SUPERVISORS
0
8
2
1
1
NIL
HORIZONTAL

SLIDER
10
130
250
163
NUM-VEHICLES
NUM-VEHICLES
0
10
3
1
1
NIL
HORIZONTAL

SLIDER
10
165
250
198
HAZARD-HOTSPOTS
HAZARD-HOTSPOTS
0
12
4
1
1
NIL
HORIZONTAL

SLIDER
10
200
250
233
HAZARD-RADIUS
HAZARD-RADIUS
2
12
6
1
1
NIL
HORIZONTAL

SLIDER
10
235
250
268
WALK-SPEED
WALK-SPEED
0.2
1.2
0.6
0.1
1
NIL
HORIZONTAL

SLIDER
10
270
250
303
PPE-BASE-ADHERENCE
PPE-BASE-ADHERENCE
0
1
0.65
0.01
1
NIL
HORIZONTAL

SLIDER
10
305
250
338
PPE-PROTECTION
PPE-PROTECTION
0
1
0.55
0.01
1
NIL
HORIZONTAL

SLIDER
10
340
250
373
COWORKER-SUPPORT
COWORKER-SUPPORT
0
1
0.35
0.01
1
NIL
HORIZONTAL

SLIDER
10
375
250
408
SUPERVISION-RADIUS
SUPERVISION-RADIUS
2
8
4
1
1
NIL
HORIZONTAL

SLIDER
10
410
250
443
TRAINING-INTERVAL
TRAINING-INTERVAL
60
1000
300
10
1
ticks
HORIZONTAL

SLIDER
10
445
250
478
TRAINING-BOOST
TRAINING-BOOST
0
0.4
0.15
0.01
1
NIL
HORIZONTAL

SLIDER
10
480
250
513
TRAINING-EFFECT
TRAINING-EFFECT
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
10
515
250
548
BREAK-INTERVAL
BREAK-INTERVAL
0
600
180
10
1
ticks
HORIZONTAL

SLIDER
10
550
250
583
RISK-SCALE
RISK-SCALE
0.05
0.6
0.25
0.01
1
NIL
HORIZONTAL

PLOT
900
10
1240
210
Incidents vs Near-Misses
NIL
NIL
0.0
3.0
0.0
10.0
true
false
""
PENS
"Incidents" 1.0 1 -16777216 true "" "plotxy 1 incidents"
"Near-misses" 1.0 1 -13345367 true "" "plotxy 2 near-misses"

PLOT
900
220
1240
420
PPE Compliance (%)
time
%
0.0
10.0
0.0
100.0
true
false
""
PENS
"default" 1.0 0 -16777216 true "" "plot ppe-compliance * 100"

PLOT
900
430
1240
610
Avg Exposure Risk
time
risk
0.0
10.0
0.0
0.5
true
false
""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-exposure-risk"

MONITOR
270
615
420
650
Incidents
incidents
0
1
11

MONITOR
430
615
620
650
Near-misses
near-misses
0
1
11

MONITOR
630
615
880
650
PPE Compliance
ppe-compliance
3
1
11

@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
