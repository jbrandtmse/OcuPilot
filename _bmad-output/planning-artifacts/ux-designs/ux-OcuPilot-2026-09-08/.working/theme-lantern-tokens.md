# V3 Lantern — token block lifted from color-themes-1.html

OcuPilot color themes — round 1 — token values and computed WCAG 2.1 contrast ratios
  Roles: Material 3 semantic roles + OcuPilot roles. "shell / on-shell / shell-edge" are proposed
  OcuPilot additions for the branded app bar and gradient end (M3 has no app-bar role).
  Classic portal precedent: only Live is styled distinctly (#da4848 red, .portalTitleServerFlagLive);
  Test / Failover / Development share one neutral indigo outline. OcuPilot keeps Live red and gives
  the other three calm, distinct hues.

===== Lantern — Light neutral chrome; the gradient lives only in the header and the panel's edge =====
  - -- light - --
  primary                              #12456F
  on-primary                           #FFFFFF
  primary-container                    #D5E5F4
  on-primary-container                 #0B2440
  secondary                            #0B7080
  on-secondary                         #FFFFFF
  secondary-container                  #C4ECF1
  on-secondary-container               #00363D
  tertiary                             #6B5E00
  on-tertiary                          #FFFFFF
  tertiary-container                   #F7EFA6
  on-tertiary-container                #2A2500
  error                                #B3261E
  on-error                             #FFFFFF
  error-container                      #F9DEDC
  on-error-container                   #410E0B
  surface                              #FAFBFC
  surface-dim                          #DCE0E3
  surface-bright                       #FFFFFF
  surface-container-lowest             #FFFFFF
  surface-container-low                #F3F5F7
  surface-container                    #ECEFF2
  surface-container-high               #E2E7EB
  surface-container-highest            #D8DEE3
  on-surface                           #1A1F24
  on-surface-variant                   #4A555E
  outline                              #6B7780
  outline-variant                      #C7CED4
  inverse-surface                      #2C3238
  inverse-on-surface                   #F0F3F5
  shell                                #0F3A5F
  on-shell                             #EAF2F7
  shell-edge                           #1C6A88
  agent-accent                         #6B5E00
  on-agent-accent                      #FFFFFF
  agent-container                      #FFF6C8
  on-agent-container                   #2A2500
  change-highlight                     #FFF3B8
  egress-warning                       #8F4300
  egress-warning-container             #FFE6CF
  restrained                           #535F68
  restrained-container                 #E6EAED
  destructive                          #B3261E
  on-destructive                       #FFFFFF
  destructive-container                #F9DEDC
  on-destructive-container             #410E0B
  success                              #1B6B39
  success-container                    #D6F1DF
  warning                              #7A5000
  warning-container                    #FFEFC2
  info                                 #1E5C9E
  info-container                       #DCEBFA
  code-surface                         #1E252B
  on-code-surface                      #DCE3E8
  focus-ring                           #12456F
  focus-ring-inner                     #FFFFFF
  server-flag-live                     #B3261E
  server-flag-live-container           #FBE1DF
  server-flag-test                     #7A5000
  server-flag-test-container           #FFEFC2
  server-flag-failover                 #5F37A6
  server-flag-failover-container       #ECE4FA
  server-flag-development              #1B6B39
  server-flag-development-container    #D6F1DF
  contrast (computed, WCAG 2.1):
    on-surface / surface                                 16.02:1  PASS (min 4.5)
    on-primary / primary                                  9.97:1  PASS (min 4.5)
    on-surface-variant / surface-container                6.61:1  PASS (min 4.5)
    agent-accent (text) / agent-container                 5.97:1  PASS (min 4.5)
    on-agent-container / agent-container                 14.14:1  PASS (min 4.5)
    on-agent-accent / agent-accent                        6.51:1  PASS (min 4.5)
    on-surface / surface-container-lowest                16.60:1  PASS (min 4.5)
    on-surface / surface-container-highest               12.23:1  PASS (min 4.5)
    on-surface-variant / surface                          7.36:1  PASS (min 4.5)
    on-primary-container / primary-container             12.19:1  PASS (min 4.5)
    on-secondary / secondary                              5.76:1  PASS (min 4.5)
    on-secondary-container / secondary-container         10.42:1  PASS (min 4.5)
    on-tertiary / tertiary                                6.51:1  PASS (min 4.5)
    on-tertiary-container / tertiary-container           13.10:1  PASS (min 4.5)
    on-error / error                                      6.54:1  PASS (min 4.5)
    on-error-container / error-container                 12.77:1  PASS (min 4.5)
    primary (as text) / surface                           9.62:1  PASS (min 4.5)
    inverse-on-surface / inverse-surface                 11.63:1  PASS (min 4.5)
    on-shell / shell                                     10.35:1  PASS (min 4.5)
    on-shell / shell-edge                                 5.35:1  PASS (min 4.5)
    on-surface (row text) / change-highlight             14.83:1  PASS (min 4.5)
    egress-warning / egress-warning-container             5.88:1  PASS (min 4.5)
    restrained / restrained-container                     5.42:1  PASS (min 4.5)
    destructive (as text) / surface                       6.31:1  PASS (min 4.5)
    on-destructive / destructive                          6.54:1  PASS (min 4.5)
    on-destructive-container / destructive-container     12.77:1  PASS (min 4.5)
    success / success-container                           5.46:1  PASS (min 4.5)
    warning / warning-container                           6.18:1  PASS (min 4.5)
    info / info-container                                 5.62:1  PASS (min 4.5)
    on-code-surface / code-surface                       11.96:1  PASS (min 4.5)
    server-flag-live / its container                      5.27:1  PASS (min 4.5)
    server-flag-test / its container                      6.18:1  PASS (min 4.5)
    server-flag-failover / its container                  6.60:1  PASS (min 4.5)
    server-flag-development / its container               5.46:1  PASS (min 4.5)
    focus-ring / surface (non-text, 3:1)                  9.62:1  PASS (min 3.0)
    focus-ring / focus-ring-inner (non-text, 3:1)         9.97:1  PASS (min 3.0)
    focus-ring-inner / primary (halo touches the button, 3:1)    9.97:1  PASS (min 3.0)
    outline / surface (non-text, 3:1)                     4.43:1  PASS (min 3.0)
  - -- dark - --
  primary                              #9CC5EA
  on-primary                           #0B2440
  primary-container                    #234A6C
  on-primary-container                 #D5E5F4
  secondary                            #6FD3DC
  on-secondary                         #003238
  secondary-container                  #00515A
  on-secondary-container               #B9EEF3
  tertiary                             #E5D25A
  on-tertiary                          #2A2500
  tertiary-container                   #4A4200
  on-tertiary-container                #F7EFA6
  error                                #F2B8B5
  on-error                             #601410
  error-container                      #8C1D18
  on-error-container                   #F9DEDC
  surface                              #141719
  surface-dim                          #0E1113
  surface-bright                       #33383C
  surface-container-lowest             #0B0E10
  surface-container-low                #1B1F22
  surface-container                    #212528
  surface-container-high               #2A2F33
  surface-container-highest            #34393E
  on-surface                           #E4E7EA
  on-surface-variant                   #B7BEC4
  outline                              #858D94
  outline-variant                      #464C52
  inverse-surface                      #E4E7EA
  inverse-on-surface                   #212528
  shell                                #0B2440
  on-shell                             #E1EAF0
  shell-edge                           #155874
  agent-accent                         #F2D64B
  on-agent-accent                      #2A2500
  agent-container                      #3A3200
  on-agent-container                   #FFF2B0
  change-highlight                     #4A4200
  egress-warning                       #FFB870
  egress-warning-container             #4A2600
  restrained                           #B0B8BF
  restrained-container                 #2A2F33
  destructive                          #F2B8B5
  on-destructive                       #601410
  destructive-container                #8C1D18
  on-destructive-container             #F9DEDC
  success                              #86DDA1
  success-container                    #0F3A22
  warning                              #F5C858
  warning-container                    #4A3600
  info                                 #9CC8F7
  info-container                       #123A63
  code-surface                         #07090B
  on-code-surface                      #D3D9DE
  focus-ring                           #9CC5EA
  focus-ring-inner                     #141719
  server-flag-live                     #FF9B93
  server-flag-live-container           #5A1410
  server-flag-test                     #F5C858
  server-flag-test-container           #4A3600
  server-flag-failover                 #CDB8F7
  server-flag-failover-container       #33205C
  server-flag-development              #86DDA1
  server-flag-development-container    #0F3A22
  contrast (computed, WCAG 2.1):
    on-surface / surface                                 14.50:1  PASS (min 4.5)
    on-primary / primary                                  8.64:1  PASS (min 4.5)
    on-surface-variant / surface-container                8.22:1  PASS (min 4.5)
    agent-accent (text) / agent-container                 8.86:1  PASS (min 4.5)
    on-agent-container / agent-container                 11.36:1  PASS (min 4.5)
    on-agent-accent / agent-accent                       10.63:1  PASS (min 4.5)
    on-surface / surface-container-lowest                15.60:1  PASS (min 4.5)
    on-surface / surface-container-highest                9.39:1  PASS (min 4.5)
    on-surface-variant / surface                          9.58:1  PASS (min 4.5)
    on-primary-container / primary-container              7.21:1  PASS (min 4.5)
    on-secondary / secondary                              7.95:1  PASS (min 4.5)
    on-secondary-container / secondary-container          7.14:1  PASS (min 4.5)
    on-tertiary / tertiary                               10.05:1  PASS (min 4.5)
    on-tertiary-container / tertiary-container            8.62:1  PASS (min 4.5)
    on-error / error                                      7.66:1  PASS (min 4.5)
    on-error-container / error-container                  7.17:1  PASS (min 4.5)
    primary (as text) / surface                           9.94:1  PASS (min 4.5)
    inverse-on-surface / inverse-surface                 12.44:1  PASS (min 4.5)
    on-shell / shell                                     12.85:1  PASS (min 4.5)
    on-shell / shell-edge                                 6.43:1  PASS (min 4.5)
    on-surface (row text) / change-highlight              8.17:1  PASS (min 4.5)
    egress-warning / egress-warning-container             7.87:1  PASS (min 4.5)
    restrained / restrained-container                     6.73:1  PASS (min 4.5)
    destructive (as text) / surface                      10.54:1  PASS (min 4.5)
    on-destructive / destructive                          7.66:1  PASS (min 4.5)
    on-destructive-container / destructive-container      7.17:1  PASS (min 4.5)
    success / success-container                           7.81:1  PASS (min 4.5)
    warning / warning-container                           7.30:1  PASS (min 4.5)
    info / info-container                                 6.64:1  PASS (min 4.5)
    on-code-surface / code-surface                       14.01:1  PASS (min 4.5)
    server-flag-live / its container                      6.72:1  PASS (min 4.5)
    server-flag-test / its container                      7.30:1  PASS (min 4.5)
    server-flag-failover / its container                  7.85:1  PASS (min 4.5)
    server-flag-development / its container               7.81:1  PASS (min 4.5)
    focus-ring / surface (non-text, 3:1)                  9.94:1  PASS (min 3.0)
    focus-ring / focus-ring-inner (non-text, 3:1)         9.94:1  PASS (min 3.0)
    focus-ring-inner / primary (halo touches the button, 3:1)    9.94:1  PASS (min 3.0)
    outline / surface (non-text, 3:1)                     5.35:1  PASS (min 3.0)
    agent-accent (wordmark) / shell — dark only          10.81:1  PASS (min 4.5)
  notes / adjustments made for AA:
    - change-highlight is the agent's pale yellow (#FFF3B8, 14.83:1 with row text) rather than aqua: the highlight means "changed by a confirmed agent write", so it borrows the agent's hue.
    - Text-bearing gradient stops end at #1C6A88 rather than the logo's brighter #2090A0, because white on #2090A0 is only 3.78:1; the brighter teal is kept for the non-text edge stripe.
