import
  std/[algorithm, json, locks, monotimes, os, random, strutils,
    tables, times],
  curly, jsony, mummy, pixie,
  bitworld/aseprite, bitworld/client, bitworld/runtime,
  bitworld/pixelfonts, bitworld/spriteprotocol, bitworld/server,
  bitworld/sprites,
  replays

const
  BoardWidthCells = 125
  BoardHeightCells = 125
  CellPixels = 9
  PlayerViewportWidth = 320
  PlayerViewportHeight = 200
  WorldWidthPixels = BoardWidthCells * CellPixels
  WorldHeightPixels = BoardHeightCells * CellPixels
  BaseTerrainY = BoardHeightCells * 31 div 50
  PieceSpawnLiftCells = 8
  PieceSpawnNudgeCells = 1
  HorizontalScrollMargin = 32
  VerticalScrollMargin = 64
  GravityPixelsPerTick = 1
  SoftGravityPixelsPerTick = 3
  MoveRepeatInterval = 5
  LockDelayTicks = 0
  LineClearLength = 8
  TerrainColor = 1'u8
  BackgroundColor = 0'u8
  TargetFps = 30
  ClearFlashTicks = TargetFps div 3
  MaxAvalancheSteps = BoardHeightCells * 2
  DefaultMaxTicks = TargetFps * 60 * 5
  GlobalSendInterval = 3
  PlayerWebSocketPath = "/player"
  HealthPath = "/healthz"
  GlobalWebSocketPath = "/global"
  AdminWebSocketPath = "/admin"
  ReplayWebSocketPath = "/replay"
  RewardWebSocketPath = "/reward"
  SendPingPayload = "ib"
  GlobalLayerId = 0
  GlobalScorePanelLayerId = 1
  GlobalReplayControlsLayerId = 2
  GlobalTopLeftLayerType = 1
  GlobalBottomCenterLayerType = 8
  GlobalUiFlag = 2
  ReplayControlsSpriteId = 55000
  ReplayControlsObjectId = 60000
  ReplayControlsWidth = 160
  ReplayControlsHeight = 20
  ReplayButtonTextY = 1
  ReplayButtonRowHeight = 10
  ReplaySpeedTextX = 86
  ReplayScrubberX = 2
  ReplayScrubberY = 12
  ReplayScrubberHeight = 6
  ReplayScrubberTrackY = 14
  ReplayScrubberWidth = ReplayControlsWidth - 2 * ReplayScrubberX
  GlobalFrameObjectBase = 10
  GlobalBackgroundSpriteId = 2
  GlobalTerrainSpriteBase = 20
  GlobalClearSpriteBase = 40
  GlobalPlayerSpriteBase = 1000
  GlobalChatSpriteBase = 50000
  GlobalBlockObjectBase = 10
  MaxGlobalObjectId = 65535
  ScorePanelDigitSpriteBase = 52000
  ScorePanelChipSpriteBase = 52100
  ScorePanelNameSpriteBase = 53100
  ScorePanelSelectedNameSpriteBase = 54100
  ScorePanelChipObjectBase = 52000
  ScorePanelDigitObjectBase = 53000
  ScorePanelNameObjectBase = 56000
  GlobalMapWidth = WorldWidthPixels
  GlobalMapHeight = (BaseTerrainY + 1) * CellPixels
  GlobalMapLayerType = 0
  GlobalZoomableFlag = 1
  BlockSpritePixels = 9
  BlockSpriteVariants = 16
  BlockPartCount = 8
  BlockPartRow = 1
  ConnectLeft = 1'u8
  ConnectRight = 2'u8
  ConnectUp = 4'u8
  ConnectDown = 8'u8
  BlockLeftEnd = 0
  BlockRightEnd = 1
  BlockTopEnd = 2
  BlockBottomEnd = 3
  BlockLeftConnection = 4
  BlockRightConnection = 5
  BlockTopConnection = 6
  BlockBottomConnection = 7
  CameraMaxY = (BaseTerrainY + 1) * CellPixels - PlayerViewportHeight
  PreviewX = PlayerViewportWidth - CellPixels * 5 - 2
  ChatMaxChars = 32
  NameMaxChars = 24
  ChatPad = 3
  ChatPointerHeight = 3
  ChatGapY = 4
  NameGapY = 2
  ChatLifetimeTicks = TargetFps * 5
  GlobalNameSpriteBase = 51000
  BackgroundRgba = RgbaColor(r: 0'u8, g: 0'u8, b: 0'u8, a: 255'u8)
  ScorePanelPipSize = 3
  ScorePanelPipGapX = 2
  ScorePanelNameGapX = 3
  ScorePanelMaxScoreChars = 16
  ScorePanelMaxRows = 128
  ScorePanelColor = RgbaColor(r: 255'u8, g: 255'u8, b: 255'u8, a: 255'u8)
  ScorePanelSelectedColor = RgbaColor(
    r: 255'u8,
    g: 245'u8,
    b: 140'u8,
    a: 255'u8
  )
  PlayerColors = [4'u8, 5'u8, 6'u8, 7'u8, 8'u8, 9'u8, 10'u8, 11'u8, 12'u8, 13'u8, 14'u8, 15'u8]

type
  RunConfig = object
    address: string
    port: int
    seed: int
    maxTicks: int
    maxGames: int
    tokens: seq[string]

  PieceKind = enum
    PieceHook
    PiecePlus
    PieceCup
    PieceCorner
    PieceTee
    PieceBar
    PieceBox
    PieceFlat

  BlockOffset = tuple[x: int, y: int]

  ClearSegment = object
    y: int
    startX: int
    endX: int

  PendingClear = object
    segment: ClearSegment
    triggerPlayerId: int
    lineLength: int
    colorCount: int
    scoreValue: int

  Player = object
    id: int
    name: string
    color: uint8
    rgbaColor: RgbaColor
    score: int
    alive: bool
    hasPiece: bool
    pieceKind: PieceKind
    nextKind: PieceKind
    rotation: int
    cellX: int
    cellY: int
    pixelY: int
    moveTicksX: int
    lockTicks: int
    deepestCellY: int
    cameraX: int
    cameraY: int
    pendingSpawnCenterX: int
    pendingSpawnTopY: int
    pendingSpawn: bool
    pendingSpawnWaitClear: bool
    message: string
    messageTicks: int

  SimServer* = object
    tickCount*: int
    players: seq[Player]
    settledColors: seq[uint8]
    settledOwners: seq[int]
    settledConnections: seq[uint8]
    settledCellIndices: seq[int]
    settledCellsDirty: bool
    terrain: seq[bool]
    blockParts: array[BlockPartCount, RgbaSprite]
    digitSprites: array[10, Sprite]
    letterSprites: seq[Sprite]
    textFont: PixelFont
    fb: Framebuffer
    rng: Rand
    nextPlayerId: int
    flashColor: uint8
    clearQueue: seq[PendingClear]
    activeClear: PendingClear
    activeClearValid: bool
    clearFlashTimer: int
    clearDisplayPlayerId: int

  GlobalViewerState = ref object
    initialized: bool
    sentOwners: seq[int]
    sentNameLabels: seq[int]
    sentScorePanelPlayers: seq[int]
    sentBackgroundSprite: bool
    sentTerrainSprites: bool
    sentClearSprites: bool
    sentScorePanelDigits: bool
    sentSelectedScorePanelPlayers: seq[int]
    selectedPlayerIndex: int
    viewPlayerIndex: int
    pendingScorePanelClick: bool
    pendingScorePanelClickX: int
    pendingScorePanelClickY: int
    mouseX: int
    mouseY: int
    mouseLayer: int
    mouseDown: bool
    mousePressed: bool
    mouseReleased: bool
    scrubbingReplay: bool
    lastReplayBarKey: int
    sentReplayControls: bool

  SocketKind = enum
    SocketUnknown
    SocketPlayer
    SocketGlobal
    SocketReward

  WebSocketAppState = object
    lock: Lock
    inputMasks: Table[WebSocket, uint8]
    lastAppliedMasks: Table[WebSocket, uint8]
    playerIndices: Table[WebSocket, int]
    playerNames: Table[WebSocket, string]
    playerSlots: Table[WebSocket, int]
    tokens: seq[string]
    chatMessages: Table[WebSocket, string]
    closedSockets: seq[WebSocket]
    spritePlayerViewers: Table[WebSocket, GlobalViewerState]
    globalViewers: Table[WebSocket, GlobalViewerState]
    rewardViewers: Table[WebSocket, bool]
    playerSendReady: Table[WebSocket, bool]
    globalSendReady: Table[WebSocket, bool]
    rewardSendReady: Table[WebSocket, bool]
    socketKinds: Table[WebSocket, SocketKind]
    resetRequested: bool
    replayServerMode: bool
    replayLoaded: bool
    pendingReplayUri: string

  ServerThreadArgs = object
    server: ptr Server
    address: string
    port: int

proc newGlobalViewerState(): GlobalViewerState =
  ## Allocates one mutable global protocol viewer state.
  GlobalViewerState(
    selectedPlayerIndex: -1,
    viewPlayerIndex: -1,
    mouseLayer: -1,
    lastReplayBarKey: -1
  )

proc viewerState(state: GlobalViewerState): GlobalViewerState =
  ## Returns an existing viewer state or allocates a new one.
  if state == nil:
    return newGlobalViewerState()
  state

proc resetProtocolState(state: GlobalViewerState) =
  ## Clears cached protocol output when a viewer changes modes.
  if state == nil:
    return
  state.initialized = false
  state.sentOwners.setLen(0)
  state.sentNameLabels.setLen(0)
  state.sentScorePanelPlayers.setLen(0)
  state.sentSelectedScorePanelPlayers.setLen(0)
  state.sentBackgroundSprite = false
  state.sentTerrainSprites = false
  state.sentClearSprites = false
  state.sentScorePanelDigits = false

proc gameDataDir(): string =
  ## Returns the Infinite Blocks data directory.
  let
    cwd = getCurrentDir()
    sourceDir = currentSourcePath().parentDir()
    candidates = [
      cwd / "data",
      cwd / "infinite_blocks" / "data",
      sourceDir / "data"
    ]
  for candidate in candidates:
    if dirExists(candidate):
      return candidate
  sourceDir / "data"

proc clientDataDir(): string =
  ## Returns the shared client data directory.
  clientDir() / "data"

proc blockSpritesPath(): string =
  ## Returns the block sprite atlas path.
  gameDataDir() / "sprites.aseprite"

proc boardIndex(x, y: int): int =
  ## Returns the flat board index for one logical cell.
  y * BoardWidthCells + x

proc inBoardBounds(x, y: int): bool =
  ## Returns true when one logical cell is inside the board.
  x >= 0 and y >= 0 and x < BoardWidthCells and y < BoardHeightCells

proc setPixelY(player: var Player, pixelY: int) =
  ## Sets the fine Y position and matching logical row.
  player.pixelY = pixelY
  player.cellY = pixelY div CellPixels

proc pieceCellPixelY(player: Player, cell: BlockOffset): int =
  ## Returns the snapped visual Y position for one piece cell.
  (player.cellY + cell.y) * CellPixels

proc worldClampPixel(x, maxValue: int): int =
  ## Clamps one world pixel coordinate against a non-negative limit.
  max(0, min(maxValue, x))

proc brightestPaletteColor(): uint8 =
  var
    bestIndex = 1
    bestValue = -1
  for i in 1 .. high(Palette):
    let swatch = Palette[i]
    let value = int(swatch.r) + int(swatch.g) + int(swatch.b)
    if value > bestValue:
      bestValue = value
      bestIndex = i
  bestIndex.uint8

proc putRect(fb: var Framebuffer, x, y, w, h: int, color: uint8) =
  for py in 0 ..< h:
    for px in 0 ..< w:
      fb.putPixel(x + px, y + py, color)

proc blitPart(
  target: var RgbaSprite,
  part: RgbaSprite,
  tint: RgbaColor
) =
  ## Blits one stained block part into a composite sprite.
  for y in 0 ..< min(target.height, part.height):
    for x in 0 ..< min(target.width, part.width):
      let color = part.rgbaSpriteAt(x, y).stainColor(tint)
      if color.a == 0'u8:
        continue
      target.putRgbaSpritePixel(x, y, color)

proc blankRgbaSprite(): RgbaSprite =
  ## Builds one empty 9x9 RGBA sprite.
  blankRgbaSprite(BlockSpritePixels, BlockSpritePixels)

proc sliceBlockPart(image: Image, index: int): RgbaSprite =
  ## Slices one 9x9 block-part sprite from the second atlas row.
  result = blankRgbaSprite()
  let
    tileX = index * BlockSpritePixels
    tileY = BlockPartRow * BlockSpritePixels
  if tileX + BlockSpritePixels > image.width or
      tileY + BlockSpritePixels > image.height:
    return
  for y in 0 ..< BlockSpritePixels:
    for x in 0 ..< BlockSpritePixels:
      let pixel = image[tileX + x, tileY + y]
      result.putRgbaSpritePixel(x, y, pixel)

proc loadBlockParts(path: string): array[BlockPartCount, RgbaSprite] =
  ## Loads the second-row 9x9 block part sprites.
  let image = readAsepriteImage(path)
  if image.width < BlockPartCount * BlockSpritePixels or
      image.height < (BlockPartRow + 1) * BlockSpritePixels:
    raise newException(
      IOError,
      "Block sprite atlas must contain 8 9x9 sprites on row 2: " & path
    )
  for i in 0 ..< result.len:
    result[i] = image.sliceBlockPart(i)

proc loadTiny5Font(): PixelFont =
  ## Loads the shared Tiny5 variable-width pixel font.
  readTiny5Font()

proc chatCharSupported(ch: char): bool =
  ## Returns true when one character can be drawn in chat.
  ch >= ' ' and ch <= '~'

proc cleanChatMessage(message: string): string =
  ## Normalizes one submitted chat message.
  for ch in message.strip():
    if result.len >= ChatMaxChars:
      return
    if ch.chatCharSupported():
      result.add(ch)

proc cleanNameLabel(name: string): string =
  ## Normalizes one player name label.
  for ch in name.strip():
    if result.len >= NameMaxChars:
      return
    if ch.chatCharSupported():
      result.add(ch)

proc chatTextWidth(sim: SimServer, text: string): int =
  ## Returns the rendered width of one chat line.
  sim.textFont.textWidth(text)

proc blitChatGlyph(
  target: var RgbaSprite,
  glyph: PixelGlyph,
  x,
  y: int,
  color: RgbaColor
) =
  ## Blits one Tiny5 glyph into a chat bubble.
  for gy in 0 ..< glyph.height:
    for gx in 0 ..< glyph.width:
      if glyph.glyphPixel(gx, gy):
        target.putRgbaSpritePixel(x + gx, y + gy, color)

proc blitChatText(
  sim: SimServer,
  target: var RgbaSprite,
  text: string,
  x,
  y: int,
  color: RgbaColor
) =
  ## Blits one tiny5 text line into a true-color sprite.
  var dx = x
  for ch in text:
    let glyph = sim.textFont.glyphAt(ch)
    target.blitChatGlyph(glyph, dx, y, color)
    dx += sim.textFont.glyphAdvance(ch)

proc textLineSprite(
  sim: SimServer,
  text: string,
  color: RgbaColor
): RgbaSprite =
  ## Builds one transparent tiny5 text label sprite.
  let
    width = max(1, sim.chatTextWidth(text) + 1)
    height = max(1, sim.textFont.height + 1)
    shadow = RgbaColor(r: 0'u8, g: 0'u8, b: 0'u8, a: 180'u8)
  result = newRgbaSprite(width, height)
  sim.blitChatText(result, text, 1, 1, shadow)
  sim.blitChatText(result, text, 0, 0, color)

proc plainTextSprite(
  sim: SimServer,
  text: string,
  color: RgbaColor
): RgbaSprite =
  ## Builds one transparent tiny5 text sprite without a shadow.
  let
    width = max(1, sim.chatTextWidth(text))
    height = max(1, sim.textFont.height)
  result = newRgbaSprite(width, height)
  sim.blitChatText(result, text, 0, 0, color)

proc compareScorePanelPlayerIndices(
  sim: SimServer,
  a,
  b: int
): int =
  ## Sorts score panel player indexes by descending score.
  result = cmp(sim.players[b].score, sim.players[a].score)
  if result == 0:
    result = cmp(sim.players[a].id, sim.players[b].id)

proc scorePanelPlayerOrder(sim: SimServer): seq[int] =
  ## Returns player indexes in score panel order.
  for i in 0 ..< sim.players.len:
    result.add(i)
  result.sort(proc(a, b: int): int =
    sim.compareScorePanelPlayerIndices(a, b)
  )

proc scorePanelScoreText(score: int): string =
  ## Returns the bounded score text used in the score panel.
  result = $score
  if result.len > ScorePanelMaxScoreChars:
    result = result[result.len - ScorePanelMaxScoreChars .. result.high]

proc scorePanelScoreWidth(sim: SimServer, order: openArray[int]): int =
  ## Returns the widest score text width.
  for playerIndex in order:
    result = max(
      result,
      sim.textFont.textWidth(scorePanelScoreText(sim.players[playerIndex].score))
    )

proc scorePanelNameText(player: Player): string =
  ## Returns the display name used in the score panel.
  result = player.name.cleanNameLabel()
  if result.len == 0:
    result = $player.id

proc scorePanelNameWidth(sim: SimServer, order: openArray[int]): int =
  ## Returns the widest player name text width.
  for playerIndex in order:
    result = max(
      result,
      sim.textFont.textWidth(sim.players[playerIndex].scorePanelNameText())
    )

proc scorePanelRowHeight(sim: SimServer): int =
  ## Returns the score panel row height.
  max(sim.textFont.lineHeight(), ScorePanelPipSize)

proc scorePanelNameX(sim: SimServer, order: openArray[int]): int =
  ## Returns the score panel name column X coordinate.
  let
    scoreColumnWidth = sim.scorePanelScoreWidth(order)
    scoreX = ScorePanelPipSize + ScorePanelPipGapX
  scoreX + scoreColumnWidth + ScorePanelNameGapX

proc scorePanelPlayerAt(sim: SimServer, x, y: int): int =
  ## Returns the player index for one score panel click.
  let order = sim.scorePanelPlayerOrder()
  if order.len == 0 or y < 0:
    return -1
  let
    rowHeight = sim.scorePanelRowHeight()
    row = y div rowHeight
  if row < 0 or row >= order.len or row >= ScorePanelMaxRows:
    return -1
  let
    playerIndex = order[row]
    name = sim.players[playerIndex].scorePanelNameText()
    nameX = sim.scorePanelNameX(order)
    nameWidth = sim.textFont.textWidth(name)
  if x < 0 or x >= nameX + nameWidth:
    return -1
  playerIndex

proc scorePanelDigitSpriteId(ch: char): int =
  ## Returns the sprite id for one score panel digit.
  ScorePanelDigitSpriteBase + ord(ch) - ord('0')

proc scorePanelPlayerKey(playerId: int): int =
  ## Returns a bounded key for score panel player sprite ids.
  playerId mod 1000

proc scorePanelChipSpriteId(playerId: int): int =
  ## Returns the sprite id for one score panel color pip.
  ScorePanelChipSpriteBase + scorePanelPlayerKey(playerId)

proc scorePanelNameSpriteId(playerId: int, selected = false): int =
  ## Returns the sprite id for one score panel player name.
  if selected:
    ScorePanelSelectedNameSpriteBase + scorePanelPlayerKey(playerId)
  else:
    ScorePanelNameSpriteBase + scorePanelPlayerKey(playerId)

proc scorePanelChipObjectId(rowIndex: int): int =
  ## Returns the object id for one score panel color pip.
  ScorePanelChipObjectBase + rowIndex

proc scorePanelDigitObjectId(rowIndex, digitIndex: int): int =
  ## Returns the object id for one score panel digit.
  ScorePanelDigitObjectBase +
    rowIndex * ScorePanelMaxScoreChars + digitIndex

proc scorePanelNameObjectId(rowIndex: int): int =
  ## Returns the object id for one score panel player name.
  ScorePanelNameObjectBase + rowIndex

proc buildScorePanelChipSprite(color: RgbaColor): RgbaSprite =
  ## Builds one solid score panel color pip sprite.
  result = newRgbaSprite(ScorePanelPipSize, ScorePanelPipSize)
  result.fillRect(
    0,
    0,
    ScorePanelPipSize,
    ScorePanelPipSize,
    color
  )

proc speechBubbleSprite(
  sim: SimServer,
  text: string,
  alpha: uint8
): RgbaSprite =
  ## Builds one tiny5 speech bubble sprite.
  let
    textWidth = max(6, sim.chatTextWidth(text))
    lineHeight = sim.textFont.height
    bodyWidth = textWidth + ChatPad * 2
    bodyHeight = lineHeight + ChatPad * 2
    fill = RgbaColor(r: 0'u8, g: 0'u8, b: 0'u8, a: alpha)
    border = RgbaColor(r: 0'u8, g: 0'u8, b: 0'u8, a: alpha)
  result = newRgbaSprite(bodyWidth, bodyHeight + ChatPointerHeight)
  for y in 0 ..< bodyHeight:
    for x in 0 ..< bodyWidth:
      result.putRgbaSpritePixel(x, y, fill)
  for x in 0 ..< bodyWidth:
    result.putRgbaSpritePixel(x, 0, border)
    result.putRgbaSpritePixel(x, bodyHeight - 1, border)
  for y in 0 ..< bodyHeight:
    result.putRgbaSpritePixel(0, y, border)
    result.putRgbaSpritePixel(bodyWidth - 1, y, border)
  let pointerX = bodyWidth div 2
  for y in 0 ..< ChatPointerHeight:
    let span = ChatPointerHeight - y - 1
    for x in pointerX - span .. pointerX + span:
      result.putRgbaSpritePixel(x, bodyHeight + y, border)
  sim.blitChatText(
    result,
    text,
    ChatPad,
    ChatPad,
    RgbaColor(r: 255'u8, g: 255'u8, b: 255'u8, a: alpha)
  )

proc composeBlockSprite(
  parts: array[BlockPartCount, RgbaSprite],
  mask: uint8,
  tint: RgbaColor
): RgbaSprite =
  ## Builds one stained full-cell sprite for a connection mask.
  result = blankRgbaSprite()
  result.blitPart(
    parts[if (mask and ConnectLeft) != 0: BlockLeftConnection
          else: BlockLeftEnd],
    tint
  )
  result.blitPart(
    parts[if (mask and ConnectRight) != 0: BlockRightConnection
          else: BlockRightEnd],
    tint
  )
  result.blitPart(
    parts[if (mask and ConnectUp) != 0: BlockTopConnection
          else: BlockTopEnd],
    tint
  )
  result.blitPart(
    parts[if (mask and ConnectDown) != 0: BlockBottomConnection
          else: BlockBottomEnd],
    tint
  )

proc normalizeCells(cells: var seq[BlockOffset]) =
  ## Moves piece cells so the top-left occupied cell is at the origin.
  var
    minX = high(int)
    minY = high(int)
  for cell in cells:
    minX = min(minX, cell.x)
    minY = min(minY, cell.y)
  for cell in cells.mitems:
    cell.x -= minX
    cell.y -= minY

proc basePieceCells(kind: PieceKind): seq[BlockOffset] =
  ## Returns the unrotated custom piece cells.
  case kind
  of PieceHook:
    @[(x: 0, y: 0), (x: 1, y: 0), (x: 0, y: 1)]
  of PiecePlus:
    @[(x: 1, y: 0), (x: 0, y: 1), (x: 1, y: 1), (x: 2, y: 1),
      (x: 1, y: 2)]
  of PieceCup:
    @[(x: 0, y: 0), (x: 1, y: 0), (x: 0, y: 1), (x: 0, y: 2),
      (x: 1, y: 2)]
  of PieceCorner:
    @[(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0), (x: 0, y: 1),
      (x: 0, y: 2)]
  of PieceTee:
    @[(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0), (x: 1, y: 1),
      (x: 1, y: 2)]
  of PieceBar:
    @[(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0), (x: 3, y: 0),
      (x: 4, y: 0)]
  of PieceBox:
    @[(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0), (x: 0, y: 1),
      (x: 1, y: 1), (x: 2, y: 1), (x: 0, y: 2), (x: 1, y: 2),
      (x: 2, y: 2)]
  of PieceFlat:
    @[(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0)]

proc rotatedCells(cells: openArray[BlockOffset]): seq[BlockOffset] =
  ## Rotates cells clockwise around their bounding box.
  var maxY = 0
  for cell in cells:
    maxY = max(maxY, cell.y)
  for cell in cells:
    result.add((x: maxY - cell.y, y: cell.x))
  result.normalizeCells()

proc pieceCells(kind: PieceKind, rotation: int): seq[BlockOffset] =
  ## Returns rotated custom piece cells.
  result = basePieceCells(kind)
  result.normalizeCells()
  for i in 0 ..< (rotation and 3):
    discard i
    result = result.rotatedCells()

proc pieceWidth(kind: PieceKind, rotation: int): int =
  ## Returns the width of one rotated piece in logical cells.
  for cell in pieceCells(kind, rotation):
    result = max(result, cell.x + 1)

proc randomPiece(sim: var SimServer): PieceKind =
  PieceKind(sim.rng.rand(high(PieceKind).ord))

proc colorForPlayer(playerId: int): uint8 =
  PlayerColors[(playerId - 1) mod PlayerColors.len]

proc colorChannel(value: float): uint8 =
  ## Converts one normalized color channel to an 8 bit value.
  let scaled = int(value * 255.0 + 0.5)
  max(0, min(255, scaled)).uint8

proc brightHsvColor(hueDegrees: int): RgbaColor =
  ## Returns a bright true-color RGBA value from an HSV hue.
  let
    hue = ((hueDegrees mod 360) + 360) mod 360
    sector = hue div 60
    fraction = float(hue mod 60) / 60.0
    saturation = 0.82
    value = 1.0
    p = value * (1.0 - saturation)
    q = value * (1.0 - saturation * fraction)
    t = value * (1.0 - saturation * (1.0 - fraction))
  var r, g, b: float
  case sector
  of 0:
    r = value
    g = t
    b = p
  of 1:
    r = q
    g = value
    b = p
  of 2:
    r = p
    g = value
    b = t
  of 3:
    r = p
    g = q
    b = value
  of 4:
    r = t
    g = p
    b = value
  else:
    r = value
    g = p
    b = q
  RgbaColor(
    r: colorChannel(r),
    g: colorChannel(g),
    b: colorChannel(b),
    a: 255'u8
  )

proc rgbaColorForPlayer(playerId: int): RgbaColor =
  ## Returns the bright HSV block color for one player id.
  brightHsvColor((playerId - 1) * 137)

proc pieceCenterPixel(player: Player): tuple[x: int, y: int] =
  ## Returns the fine pixel center for one active piece.
  if not player.hasPiece:
    return (
      player.cameraX + PlayerViewportWidth div 2,
      player.cameraY + VerticalScrollMargin
    )
  var
    minX = high(int)
    maxX = low(int)
    minY = high(int)
    maxY = low(int)
  for cell in pieceCells(player.pieceKind, player.rotation):
    let
      x = (player.cellX + cell.x) * CellPixels
      y = player.pieceCellPixelY(cell)
    minX = min(minX, x)
    maxX = max(maxX, x + CellPixels - 1)
    minY = min(minY, y)
    maxY = max(maxY, y + CellPixels - 1)
  ((minX + maxX) div 2, (minY + maxY) div 2)

proc pieceBounds(player: Player): tuple[minX, maxX, minY, maxY: int] =
  result.minX = high(int)
  result.maxX = low(int)
  result.minY = high(int)
  result.maxY = low(int)
  for cell in pieceCells(player.pieceKind, player.rotation):
    let
      x = player.cellX + cell.x
      y = player.cellY + cell.y
    result.minX = min(result.minX, x)
    result.maxX = max(result.maxX, x)
    result.minY = min(result.minY, y)
    result.maxY = max(result.maxY, y)

proc pieceBottomY(player: Player): int =
  ## Returns the lowest occupied row for one active piece.
  if not player.hasPiece:
    return low(int)
  player.pieceBounds().maxY

proc piecePixelBounds(player: Player): tuple[minX, maxX, minY, maxY: int] =
  ## Returns the snapped pixel bounds for one active piece.
  result.minX = high(int)
  result.maxX = low(int)
  result.minY = high(int)
  result.maxY = low(int)
  for cell in pieceCells(player.pieceKind, player.rotation):
    let
      x = (player.cellX + cell.x) * CellPixels
      y = player.pieceCellPixelY(cell)
    result.minX = min(result.minX, x)
    result.maxX = max(result.maxX, x + CellPixels - 1)
    result.minY = min(result.minY, y)
    result.maxY = max(result.maxY, y + CellPixels - 1)

proc clampCamera(player: var Player) =
  player.cameraX = worldClampPixel(
    player.cameraX,
    WorldWidthPixels - PlayerViewportWidth
  )
  player.cameraY = worldClampPixel(player.cameraY, CameraMaxY)

proc positionCameraForSpawn(player: var Player, recenterHoriz: bool) =
  if not player.hasPiece:
    return
  let pixelBounds = piecePixelBounds(player)
  if recenterHoriz:
    let center = pieceCenterPixel(player)
    player.cameraX = center.x - PlayerViewportWidth div 2
  player.cameraY = pixelBounds.minY - VerticalScrollMargin
  player.clampCamera()

proc updateCameraForPlayer(player: var Player) =
  if not player.hasPiece:
    return

  let pixelBounds = piecePixelBounds(player)
  if pixelBounds.minX - player.cameraX < HorizontalScrollMargin:
    player.cameraX = pixelBounds.minX - HorizontalScrollMargin
  elif pixelBounds.maxX - player.cameraX >
      PlayerViewportWidth - 1 - HorizontalScrollMargin:
    player.cameraX = pixelBounds.maxX -
      (PlayerViewportWidth - 1 - HorizontalScrollMargin)

  if pixelBounds.maxY - player.cameraY >
      PlayerViewportHeight - 1 - VerticalScrollMargin:
    player.cameraY = pixelBounds.maxY -
      (PlayerViewportHeight - 1 - VerticalScrollMargin)

  player.clampCamera()

proc hasInt(values: openArray[int], value: int): bool =
  ## Returns true when a small integer list contains a value.
  for item in values:
    if item == value:
      return true

proc addUniqueInt(values: var seq[int], value: int) =
  ## Adds an integer to a small list if it is not already present.
  if values.hasInt(value):
    return
  values.add(value)

proc canPlaceStatic(
  sim: SimServer,
  cellX, cellY: int,
  kind: PieceKind,
  rotation: int
): bool =
  ## Returns true when a piece avoids terrain and settled blocks.
  for cell in pieceCells(kind, rotation):
    let
      x = cellX + cell.x
      y = cellY + cell.y
    if not inBoardBounds(x, y):
      return false
    let index = boardIndex(x, y)
    if sim.terrain[index] or sim.settledColors[index] != 0:
      return false
  true

proc canPlaceStaticPixels(
  sim: SimServer,
  cellX, pixelY: int,
  kind: PieceKind,
  rotation: int
): bool =
  ## Returns true when a fine-positioned piece's logical cells are free.
  sim.canPlaceStatic(cellX, pixelY div CellPixels, kind, rotation)

proc playerHasCell(player: Player, x, y: int): bool =
  ## Returns true when one active piece occupies a board cell.
  if not player.alive or not player.hasPiece:
    return false
  for cell in pieceCells(player.pieceKind, player.rotation):
    if player.cellX + cell.x == x and player.cellY + cell.y == y:
      return true

proc activeBlockerAt(
  sim: SimServer,
  ignoredPlayers: openArray[int],
  x, y: int
): int =
  ## Returns the active player index occupying a cell, or -1.
  for i in 0 ..< sim.players.len:
    if ignoredPlayers.hasInt(i):
      continue
    if sim.players[i].playerHasCell(x, y):
      return i
  -1

proc canPlaceIgnoring(
  sim: SimServer,
  cellX, cellY: int,
  kind: PieceKind,
  rotation: int,
  ignoredPlayers: openArray[int]
): bool =
  ## Returns true when a piece avoids static blocks and active players.
  if not sim.canPlaceStatic(cellX, cellY, kind, rotation):
    return false
  for cell in pieceCells(kind, rotation):
    let
      x = cellX + cell.x
      y = cellY + cell.y
    if sim.activeBlockerAt(ignoredPlayers, x, y) >= 0:
      return false
  true

proc canPlacePixelsIgnoring(
  sim: SimServer,
  cellX, pixelY: int,
  kind: PieceKind,
  rotation: int,
  ignoredPlayers: openArray[int]
): bool =
  ## Returns true when a fine-positioned piece's logical cells are free.
  sim.canPlaceIgnoring(
    cellX,
    pixelY div CellPixels,
    kind,
    rotation,
    ignoredPlayers
  )

proc canPlace(
  sim: SimServer,
  cellX, cellY: int,
  kind: PieceKind,
  rotation: int
): bool =
  ## Returns true when a piece can occupy a board position.
  let ignoredPlayers: array[0, int] = []
  sim.canPlacePixelsIgnoring(
    cellX,
    cellY * CellPixels,
    kind,
    rotation,
    ignoredPlayers
  )

proc blockingPlayersForPixels(
  sim: SimServer,
  playerIndex, cellX, pixelY, rotation: int,
  ignoredPlayers: openArray[int]
): seq[int] =
  ## Returns active player indices blocking a fine-positioned piece.
  let player = sim.players[playerIndex]
  for cell in pieceCells(player.pieceKind, rotation):
    let
      cellY = pixelY div CellPixels
      x = cellX + cell.x
      y = cellY + cell.y
      blocker = sim.activeBlockerAt(ignoredPlayers, x, y)
    if blocker >= 0:
      result.addUniqueInt(blocker)

proc collectPushes(
  sim: SimServer,
  playerIndex, dx, dy: int,
  movingPlayers: var seq[int]
): bool =
  ## Collects all active pieces that must move for one push to succeed.
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return false
  if movingPlayers.hasInt(playerIndex):
    return true
  if not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return false

  movingPlayers.add(playerIndex)
  let
    player = sim.players[playerIndex]
    nextX = player.cellX + dx
    nextPixelY = player.pixelY + dy * CellPixels
  if not sim.canPlaceStaticPixels(
    nextX,
    nextPixelY,
    player.pieceKind,
    player.rotation
  ):
    return false

  let blockers = sim.blockingPlayersForPixels(
    playerIndex,
    nextX,
    nextPixelY,
    player.rotation,
    movingPlayers
  )
  for blocker in blockers:
    if not sim.collectPushes(blocker, dx, dy, movingPlayers):
      return false
  true

proc moveCollectedPlayers(
  sim: var SimServer,
  movingPlayers: openArray[int],
  dx, dy: int
) =
  ## Applies one already-validated push movement.
  if movingPlayers.len == 0:
    return
  for i in countdown(movingPlayers.high, 0):
    let playerIndex = movingPlayers[i]
    if playerIndex < 0 or playerIndex >= sim.players.len:
      continue
    sim.players[playerIndex].cellX += dx
    if dy != 0:
      sim.players[playerIndex].setPixelY(
        sim.players[playerIndex].pixelY + dy * CellPixels
      )

proc refreshLockDepth(sim: var SimServer, playerIndex: int) =
  ## Resets lock delay only after a piece reaches a new lower row.
  if playerIndex < 0 or
      playerIndex >= sim.players.len or
      not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return
  let bottomY = sim.players[playerIndex].pieceBottomY()
  if bottomY > sim.players[playerIndex].deepestCellY:
    sim.players[playerIndex].deepestCellY = bottomY
    sim.players[playerIndex].lockTicks = 0

proc drawPiece(
  fb: var Framebuffer,
  player: Player,
  cameraX, cameraY: int,
  color: uint8
) =
  for cell in pieceCells(player.pieceKind, player.rotation):
    let
      worldX = (player.cellX + cell.x) * CellPixels
      worldY = player.pieceCellPixelY(cell)
      screenX = worldX - cameraX
      screenY = worldY - cameraY
    fb.putRect(screenX, screenY, CellPixels, CellPixels, color)

proc drawPreview(
  fb: var Framebuffer,
  kind: PieceKind,
  color: uint8,
  screenX, screenY: int
) =
  let previewPlayer = Player(pieceKind: kind, rotation: 0, cellX: 0, cellY: 0)
  for cell in pieceCells(previewPlayer.pieceKind, previewPlayer.rotation):
    fb.putRect(screenX + cell.x * CellPixels, screenY + cell.y * CellPixels, CellPixels, CellPixels, color)

proc blitSolidSprite(
  fb: var Framebuffer,
  sprite: Sprite,
  screenX, screenY: int,
  color: uint8
) =
  for y in 0 ..< sprite.height:
    for x in 0 ..< sprite.width:
      if sprite.pixels[sprite.spriteIndex(x, y)] != TransparentColorIndex:
        fb.putPixel(screenX + x, screenY + y, color)

proc renderNumber(
  fb: var Framebuffer,
  digitSprites: array[10, Sprite],
  value, screenX, screenY: int,
  showZero = true
): int =
  if value == 0 and not showZero:
    return 0
  let text = $max(0, value)
  var x = screenX
  for ch in text:
    let digit = ord(ch) - ord('0')
    fb.blitSprite(digitSprites[digit], x, screenY, 0, 0)
    x += digitSprites[digit].width
  x - screenX

proc renderSolidNumber(
  fb: var Framebuffer,
  digitSprites: array[10, Sprite],
  value, screenX, screenY: int,
  color: uint8
): int =
  let text = $max(0, value)
  var x = screenX
  for ch in text:
    let digit = ord(ch) - ord('0')
    fb.blitSolidSprite(digitSprites[digit], x, screenY, color)
    x += digitSprites[digit].width
  x - screenX

proc renderSolidText(
  fb: var Framebuffer,
  letterSprites: seq[Sprite],
  text: string,
  screenX, screenY: int,
  color: uint8
): int =
  var x = screenX
  for ch in text:
    if ch == ' ':
      x += 6
      continue
    let idx = letterIndex(ch)
    if idx >= 0 and idx < letterSprites.len:
      fb.blitSolidSprite(letterSprites[idx], x, screenY, color)
    x += 6
  x - screenX

proc initSimServer*(seed: int): SimServer =
  result.rng = initRand(seed)
  result.settledColors = newSeq[uint8](BoardWidthCells * BoardHeightCells)
  result.settledOwners = newSeq[int](BoardWidthCells * BoardHeightCells)
  result.settledConnections = newSeq[uint8](BoardWidthCells * BoardHeightCells)
  result.settledCellIndices = @[]
  result.settledCellsDirty = false
  result.terrain = newSeq[bool](BoardWidthCells * BoardHeightCells)
  result.blockParts = loadBlockParts(blockSpritesPath())
  result.fb = initFramebuffer()
  loadPalette(clientDataDir() / "pallete.png")
  result.flashColor = brightestPaletteColor()
  result.digitSprites = loadDigitSprites(clientDataDir() / "numbers.png")
  result.letterSprites = loadLetterSprites(clientDataDir() / "letters.png")
  result.textFont = loadTiny5Font()

  for x in 0 ..< BoardWidthCells:
    result.terrain[boardIndex(x, BaseTerrainY)] = true

proc spawnXLimits(
  kind: PieceKind,
  rotation: int
): tuple[minX, maxX: int] =
  ## Returns the inclusive horizontal range that keeps a piece in bounds.
  var
    minOffset = high(int)
    maxOffset = low(int)
  for cell in pieceCells(kind, rotation):
    minOffset = min(minOffset, cell.x)
    maxOffset = max(maxOffset, cell.x)
  (
    minX: -minOffset,
    maxX: BoardWidthCells - 1 - maxOffset
  )

proc findSpawnInColumn(
  sim: SimServer,
  kind: PieceKind,
  cellX, desiredTopY: int
): tuple[found: bool, x: int, y: int] =
  ## Searches one column for a nearby spawn row.
  for offset in 0 ..< 80:
    let topY = max(0, desiredTopY - offset)
    if sim.canPlace(cellX, topY, kind, 0):
      return (true, cellX, topY)
  for offset in 1 ..< 40:
    let topY = min(BoardHeightCells - 4, desiredTopY + offset)
    if sim.canPlace(cellX, topY, kind, 0):
      return (true, cellX, topY)
  for topY in 0 ..< BaseTerrainY:
    if sim.canPlace(cellX, topY, kind, 0):
      return (true, cellX, topY)

proc clearSpawnPocket(sim: var SimServer, kind: PieceKind, cellX, cellY: int) =
  ## Clears settled blocks from a forced respawn pocket.
  for cell in pieceCells(kind, 0):
    let
      x = cellX + cell.x
      y = cellY + cell.y
    if not inBoardBounds(x, y):
      continue
    if inBoardBounds(x - 1, y):
      let leftIndex = boardIndex(x - 1, y)
      sim.settledConnections[leftIndex] =
        sim.settledConnections[leftIndex] and not ConnectRight
    if inBoardBounds(x + 1, y):
      let rightIndex = boardIndex(x + 1, y)
      sim.settledConnections[rightIndex] =
        sim.settledConnections[rightIndex] and not ConnectLeft
    if inBoardBounds(x, y - 1):
      let upIndex = boardIndex(x, y - 1)
      sim.settledConnections[upIndex] =
        sim.settledConnections[upIndex] and not ConnectDown
    if inBoardBounds(x, y + 1):
      let downIndex = boardIndex(x, y + 1)
      sim.settledConnections[downIndex] =
        sim.settledConnections[downIndex] and not ConnectUp
    let index = boardIndex(x, y)
    if sim.terrain[index]:
      continue
    sim.settledColors[index] = 0
    sim.settledOwners[index] = 0
    sim.settledConnections[index] = 0
  sim.settledCellsDirty = true

proc canForceSpawnAt(
  sim: SimServer,
  kind: PieceKind,
  cellX,
  cellY: int
): bool =
  ## Returns true when a forced spawn pocket avoids terrain and players.
  let ignoredPlayers: array[0, int] = []
  for cell in pieceCells(kind, 0):
    let
      x = cellX + cell.x
      y = cellY + cell.y
    if not inBoardBounds(x, y):
      return false
    if sim.terrain[boardIndex(x, y)]:
      return false
    if sim.activeBlockerAt(ignoredPlayers, x, y) >= 0:
      return false
  true

proc findForcedSpawnPosition(
  sim: var SimServer,
  kind: PieceKind
): tuple[found: bool, x: int, y: int] =
  ## Creates a spawn pocket when ordinary relocation cannot find one.
  let limits = spawnXLimits(kind, 0)
  if limits.minX > limits.maxX:
    return

  let
    columnCount = limits.maxX - limits.minX + 1
    startX = limits.minX + sim.rng.rand(columnCount - 1)
  for i in 0 ..< columnCount:
    let cellX = limits.minX + ((startX - limits.minX + i) mod columnCount)
    for cellY in 0 ..< BaseTerrainY:
      if not sim.canForceSpawnAt(kind, cellX, cellY):
        continue
      sim.clearSpawnPocket(kind, cellX, cellY)
      if sim.canPlace(cellX, cellY, kind, 0):
        return (found: true, x: cellX, y: cellY)

proc findSpawnPosition(
  sim: var SimServer,
  kind: PieceKind,
  desiredCenterX, desiredTopY: int
): tuple[found: bool, x: int, y: int] =
  ## Finds a spawn location, using a random column when the target is blocked.
  let desiredX = desiredCenterX - pieceWidth(kind, 0) div 2 +
    PieceSpawnNudgeCells
  result = sim.findSpawnInColumn(kind, desiredX, desiredTopY)
  if result.found:
    return

  let limits = spawnXLimits(kind, 0)
  if limits.minX > limits.maxX:
    return

  let
    columnCount = limits.maxX - limits.minX + 1
    startX = limits.minX + sim.rng.rand(columnCount - 1)
  for i in 0 ..< columnCount:
    let cellX = limits.minX + ((startX - limits.minX + i) mod columnCount)
    if cellX == desiredX:
      continue
    result = sim.findSpawnInColumn(kind, cellX, desiredTopY)
    if result.found:
      return
  result = sim.findForcedSpawnPosition(kind)

proc respawnPlayer(sim: var SimServer, playerIndex, centerX, topY: int, recenterHoriz = false) =
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return

  let nextKind = sim.players[playerIndex].nextKind
  let spawn = sim.findSpawnPosition(nextKind, centerX, topY)
  if not spawn.found:
    sim.players[playerIndex].alive = true
    sim.players[playerIndex].hasPiece = false
    sim.players[playerIndex].pendingSpawn = true
    sim.players[playerIndex].pendingSpawnCenterX = centerX
    sim.players[playerIndex].pendingSpawnTopY = topY
    sim.players[playerIndex].pendingSpawnWaitClear = false
    return

  sim.players[playerIndex].alive = true
  sim.players[playerIndex].hasPiece = true
  sim.players[playerIndex].pieceKind = nextKind
  sim.players[playerIndex].nextKind = sim.randomPiece()
  sim.players[playerIndex].rotation = 0
  sim.players[playerIndex].cellX = spawn.x
  sim.players[playerIndex].setPixelY(spawn.y * CellPixels)
  sim.players[playerIndex].moveTicksX = 0
  sim.players[playerIndex].lockTicks = 0
  sim.players[playerIndex].deepestCellY =
    sim.players[playerIndex].pieceBottomY()
  sim.players[playerIndex].positionCameraForSpawn(recenterHoriz)
  sim.players[playerIndex].pendingSpawn = false
  sim.players[playerIndex].pendingSpawnWaitClear = false

proc addPlayer*(sim: var SimServer, name: string): int =
  inc sim.nextPlayerId
  let playerId = sim.nextPlayerId
  sim.players.add Player(
    id: playerId,
    name: name,
    color: colorForPlayer(playerId),
    rgbaColor: rgbaColorForPlayer(playerId),
    score: 0,
    alive: true,
    hasPiece: false,
    pieceKind: sim.randomPiece(),
    nextKind: sim.randomPiece()
  )
  let playerIndex = sim.players.high
  sim.respawnPlayer(playerIndex, BoardWidthCells div 2, BaseTerrainY - PieceSpawnLiftCells, recenterHoriz = true)
  playerIndex

proc tryMove(sim: var SimServer, playerIndex, dx, dy: int): bool =
  ## Moves one active piece and pushes any blocking active pieces.
  if playerIndex < 0 or
      playerIndex >= sim.players.len or
      not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return false
  if dx == 0 and dy == 0:
    return true

  var movingPlayers: seq[int] = @[]
  if not sim.collectPushes(playerIndex, dx, dy, movingPlayers):
    return false
  sim.moveCollectedPlayers(movingPlayers, dx, dy)
  true

proc tryMovePixelsY(
  sim: var SimServer,
  playerIndex,
  dyPixels: int
): bool =
  ## Moves one active piece down by fine pixels.
  if playerIndex < 0 or
      playerIndex >= sim.players.len or
      not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return false
  if dyPixels <= 0:
    return true

  let ignoredPlayers = [playerIndex]
  for i in 0 ..< dyPixels:
    let
      player = sim.players[playerIndex]
      targetPixelY = player.pixelY + 1
    if not sim.canPlacePixelsIgnoring(
      player.cellX,
      targetPixelY,
      player.pieceKind,
      player.rotation,
      ignoredPlayers
    ):
      return i > 0
    sim.players[playerIndex].setPixelY(targetPixelY)
  true

proc tryRotate(sim: var SimServer, playerIndex: int): bool =
  ## Rotates one active piece when the target cells are unoccupied.
  if playerIndex < 0 or
      playerIndex >= sim.players.len or
      not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return false

  let
    ignoredPlayers = [playerIndex]
    nextRotation = (sim.players[playerIndex].rotation + 1) and 3
  for kick in [
    (x: 0, y: 0),
    (x: -1, y: 0),
    (x: 1, y: 0),
    (x: -2, y: 0),
    (x: 2, y: 0)
  ]:
    let
      nextX = sim.players[playerIndex].cellX + kick.x
      nextPixelY = sim.players[playerIndex].pixelY + kick.y * CellPixels
    if sim.canPlacePixelsIgnoring(
      nextX,
      nextPixelY,
      sim.players[playerIndex].pieceKind,
      nextRotation,
      ignoredPlayers
    ):
      sim.players[playerIndex].rotation = nextRotation
      sim.players[playerIndex].cellX = nextX
      sim.players[playerIndex].setPixelY(nextPixelY)
      return true
  false

proc addUnique(values: var seq[int], value: int) =
  for existing in values:
    if existing == value:
      return
  values.add(value)

proc hasPieceOffset(cells: openArray[BlockOffset], x, y: int): bool =
  ## Returns true when a piece offset list contains one cell.
  for cell in cells:
    if cell.x == x and cell.y == y:
      return true

proc offsetConnectionMask(
  cells: openArray[BlockOffset],
  cell: BlockOffset
): uint8 =
  ## Returns the local connection mask for one piece cell.
  if cells.hasPieceOffset(cell.x - 1, cell.y):
    result = result or ConnectLeft
  if cells.hasPieceOffset(cell.x + 1, cell.y):
    result = result or ConnectRight
  if cells.hasPieceOffset(cell.x, cell.y - 1):
    result = result or ConnectUp
  if cells.hasPieceOffset(cell.x, cell.y + 1):
    result = result or ConnectDown

proc pieceConnectionMask(
  kind: PieceKind,
  rotation: int,
  cell: BlockOffset
): uint8 =
  ## Returns the connection mask for one block inside a piece.
  let cells = pieceCells(kind, rotation)
  cells.offsetConnectionMask(cell)

proc playerConnectionMask(player: Player, cell: BlockOffset): uint8 =
  ## Returns the connection mask for one active player block.
  pieceConnectionMask(player.pieceKind, player.rotation, cell)

proc terrainConnectionMask(x: int): uint8 =
  ## Returns the horizontal connection mask for one floor cell.
  if x > 0:
    result = result or ConnectLeft
  if x < BoardWidthCells - 1:
    result = result or ConnectRight

proc neighborFor(
  x, y: int,
  direction: uint8
): tuple[x: int, y: int] =
  ## Returns the neighboring cell for one connection bit.
  case direction
  of ConnectLeft:
    (x - 1, y)
  of ConnectRight:
    (x + 1, y)
  of ConnectUp:
    (x, y - 1)
  else:
    (x, y + 1)

proc oppositeConnection(direction: uint8): uint8 =
  ## Returns the opposite connection bit.
  case direction
  of ConnectLeft:
    ConnectRight
  of ConnectRight:
    ConnectLeft
  of ConnectUp:
    ConnectDown
  else:
    ConnectUp

proc clearConnectionTo(
  sim: var SimServer,
  x, y: int,
  direction: uint8
) =
  ## Removes one stored connection from an occupied settled cell.
  if not inBoardBounds(x, y):
    return
  let index = boardIndex(x, y)
  if sim.settledColors[index] == 0:
    return
  sim.settledConnections[index] =
    sim.settledConnections[index] and not direction

proc severConnectionsToSegment(sim: var SimServer, segment: ClearSegment) =
  ## Turns connections into end caps before a row segment is removed.
  for x in segment.startX .. segment.endX:
    sim.clearConnectionTo(x - 1, segment.y, ConnectRight)
    sim.clearConnectionTo(x + 1, segment.y, ConnectLeft)
    sim.clearConnectionTo(x, segment.y - 1, ConnectDown)
    sim.clearConnectionTo(x, segment.y + 1, ConnectUp)

proc pruneSettledConnections(sim: var SimServer) =
  ## Removes any stored connections that no longer have a matching neighbor.
  for y in 0 ..< BoardHeightCells:
    for x in 0 ..< BoardWidthCells:
      let index = boardIndex(x, y)
      if sim.settledColors[index] == 0:
        sim.settledConnections[index] = 0
        continue
      var mask = sim.settledConnections[index]
      for direction in [ConnectLeft, ConnectRight, ConnectUp, ConnectDown]:
        if (mask and direction) == 0:
          continue
        let neighbor = neighborFor(x, y, direction)
        if not inBoardBounds(neighbor.x, neighbor.y):
          mask = mask and not direction
          continue
        let neighborIndex = boardIndex(neighbor.x, neighbor.y)
        if sim.settledColors[neighborIndex] == 0 or
            (sim.settledConnections[neighborIndex] and
              direction.oppositeConnection()) == 0:
          mask = mask and not direction
      sim.settledConnections[index] = mask

proc buildSettledComponents(
  sim: SimServer,
  componentIds: var seq[int]
): seq[seq[int]] =
  ## Builds settled block components using stored connection masks.
  componentIds = newSeq[int](BoardWidthCells * BoardHeightCells)
  for i in 0 ..< componentIds.len:
    componentIds[i] = -1

  var stack: seq[int] = @[]
  for index in 0 ..< componentIds.len:
    if sim.settledColors[index] == 0 or componentIds[index] >= 0:
      continue

    let componentId = result.len
    result.add(@[])
    componentIds[index] = componentId
    stack.setLen(0)
    stack.add(index)

    while stack.len > 0:
      let current = stack[^1]
      stack.setLen(stack.len - 1)
      result[componentId].add(current)
      let
        x = current mod BoardWidthCells
        y = current div BoardWidthCells
        mask = sim.settledConnections[current]
      for direction in [ConnectLeft, ConnectRight, ConnectUp, ConnectDown]:
        if (mask and direction) == 0:
          continue
        let neighbor = neighborFor(x, y, direction)
        if not inBoardBounds(neighbor.x, neighbor.y):
          continue
        let neighborIndex = boardIndex(neighbor.x, neighbor.y)
        if sim.settledColors[neighborIndex] == 0:
          continue
        if (sim.settledConnections[neighborIndex] and
            direction.oppositeConnection()) == 0:
          continue
        if componentIds[neighborIndex] >= 0:
          continue
        componentIds[neighborIndex] = componentId
        stack.add(neighborIndex)

proc componentHasSupport(
  sim: SimServer,
  component: openArray[int],
  componentIds: openArray[int],
  componentId: int
): bool =
  ## Returns true when a component is supported by terrain or other blocks.
  for index in component:
    let
      x = index mod BoardWidthCells
      y = index div BoardWidthCells
      belowY = y + 1
    if belowY >= BoardHeightCells:
      return true
    let belowIndex = boardIndex(x, belowY)
    if sim.terrain[belowIndex]:
      return true
    if sim.settledColors[belowIndex] != 0 and
        componentIds[belowIndex] != componentId:
      return true

proc unsupportedSettledComponents(sim: SimServer): seq[seq[int]] =
  ## Returns settled components that can fall one row.
  var componentIds: seq[int]
  let components = sim.buildSettledComponents(componentIds)
  for componentId, component in components:
    if not sim.componentHasSupport(
      component,
      componentIds,
      componentId
    ):
      result.add(component)

proc canDropComponentsOneRow(
  sim: SimServer,
  components: openArray[seq[int]],
  moving: openArray[bool]
): bool =
  ## Returns true when all falling components can move down one row.
  for component in components:
    for sourceIndex in component:
      let destinationIndex = sourceIndex + BoardWidthCells
      if destinationIndex >= moving.len:
        return false
      if sim.terrain[destinationIndex]:
        return false
      if sim.settledColors[destinationIndex] != 0 and
          not moving[destinationIndex]:
        return false
  true

proc dropSettledComponentsOneRow(
  sim: var SimServer,
  components: openArray[seq[int]]
): bool =
  ## Drops settled components one row while preserving block data.
  var
    moving = newSeq[bool](BoardWidthCells * BoardHeightCells)
    sources: seq[int] = @[]
    destinations: seq[int] = @[]
    colors: seq[uint8] = @[]
    owners: seq[int] = @[]
    connections: seq[uint8] = @[]

  for component in components:
    for sourceIndex in component:
      moving[sourceIndex] = true
      sources.add(sourceIndex)
      destinations.add(sourceIndex + BoardWidthCells)
      colors.add(sim.settledColors[sourceIndex])
      owners.add(sim.settledOwners[sourceIndex])
      connections.add(sim.settledConnections[sourceIndex])

  if sources.len == 0 or not sim.canDropComponentsOneRow(
    components,
    moving
  ):
    return false

  for sourceIndex in sources:
    sim.settledColors[sourceIndex] = 0
    sim.settledOwners[sourceIndex] = 0
    sim.settledConnections[sourceIndex] = 0

  for i in 0 ..< sources.len:
    let destinationIndex = destinations[i]
    sim.settledColors[destinationIndex] = colors[i]
    sim.settledOwners[destinationIndex] = owners[i]
    sim.settledConnections[destinationIndex] = connections[i]
  true

proc dropUnsupportedSettledBlocks(sim: var SimServer): bool =
  ## Drops unsupported settled components until the board is stable.
  for _ in 0 ..< MaxAvalancheSteps:
    sim.pruneSettledConnections()
    let components = sim.unsupportedSettledComponents()
    if components.len == 0:
      break
    if not sim.dropSettledComponentsOneRow(components):
      break
    result = true

  sim.pruneSettledConnections()
  if result:
    sim.settledCellsDirty = true

proc hasStaticSupportBelow(sim: SimServer, playerIndex: int): bool =
  ## Returns true when terrain or settled blocks support a player piece.
  if playerIndex < 0 or
      playerIndex >= sim.players.len or
      not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return false
  let player = sim.players[playerIndex]
  not sim.canPlaceStaticPixels(
    player.cellX,
    player.pixelY + 1,
    player.pieceKind,
    player.rotation
  )

proc findClearSegments(sim: SimServer): seq[ClearSegment] =
  for y in countdown(BoardHeightCells - 1, 0):
    var x = 0
    while x < BoardWidthCells:
      let index = boardIndex(x, y)
      if sim.settledColors[index] == 0:
        inc x
        continue
      let startX = x
      while x < BoardWidthCells and sim.settledColors[boardIndex(x, y)] != 0:
        inc x
      let endX = x - 1
      if endX - startX + 1 >= LineClearLength:
        result.add ClearSegment(y: y, startX: startX, endX: endX)

proc sameSegment(a, b: ClearSegment): bool =
  ## Returns true when two clear segments identify the same row span.
  a.y == b.y and a.startX == b.startX and a.endX == b.endX

proc segmentQueued(sim: SimServer, segment: ClearSegment): bool =
  ## Returns true when a clear segment is already active or queued.
  if sim.activeClearValid and sim.activeClear.segment.sameSegment(segment):
    return true
  for clear in sim.clearQueue:
    if clear.segment.sameSegment(segment):
      return true

proc segmentStillFilled(sim: SimServer, segment: ClearSegment): bool =
  ## Returns true when a queued clear segment still contains a full row span.
  if segment.endX - segment.startX + 1 < LineClearLength:
    return false
  for x in segment.startX .. segment.endX:
    if not inBoardBounds(x, segment.y):
      return false
    if sim.settledColors[boardIndex(x, segment.y)] == 0:
      return false
  true

proc awardPendingClear(sim: var SimServer, clear: PendingClear) =
  for player in sim.players.mitems:
    if player.id == clear.triggerPlayerId:
      player.score += clear.scoreValue
      break

proc clearSegments(sim: var SimServer, segments: openArray[ClearSegment]) =
  for segment in segments:
    sim.severConnectionsToSegment(segment)
    for x in segment.startX .. segment.endX:
      let index = boardIndex(x, segment.y)
      sim.settledColors[index] = 0
      sim.settledOwners[index] = 0
      sim.settledConnections[index] = 0
  sim.settledCellsDirty = true

proc rebuildSettledCellIndices(sim: var SimServer) =
  ## Rebuilds the compact list of occupied settled cells.
  sim.settledCellIndices.setLen(0)
  for y in 0 ..< BoardHeightCells:
    for x in 0 ..< BoardWidthCells:
      let index = boardIndex(x, y)
      if sim.settledColors[index] != 0:
        sim.settledCellIndices.add(index)
  sim.settledCellsDirty = false

proc pendingClearFor(sim: SimServer, segment: ClearSegment, triggerPlayerId: int): PendingClear =
  var
    ownersSeen: seq[int]
    lineLength = segment.endX - segment.startX + 1
  for x in segment.startX .. segment.endX:
    let index = boardIndex(x, segment.y)
    if sim.settledColors[index] != 0:
      let owner = sim.settledOwners[index]
      if owner > 0:
        ownersSeen.addUnique(owner)
  PendingClear(
    segment: segment,
    triggerPlayerId: triggerPlayerId,
    lineLength: lineLength,
    colorCount: max(1, ownersSeen.len),
    scoreValue: lineLength * max(1, ownersSeen.len)
  )

proc enqueueDetectedClears(sim: var SimServer, triggerPlayerId: int): bool =
  let segments = sim.findClearSegments()
  if segments.len == 0:
    return false
  for segment in segments:
    if sim.segmentQueued(segment):
      continue
    sim.clearQueue.add sim.pendingClearFor(segment, triggerPlayerId)
    result = true

proc releaseClearSpawnWait(sim: var SimServer, triggerPlayerId: int) =
  ## Releases pending spawns that were waiting on this player's clear.
  for player in sim.players.mitems:
    if player.id == triggerPlayerId and player.pendingSpawnWaitClear:
      player.pendingSpawnWaitClear = false

proc clearQueuedFor(sim: SimServer, triggerPlayerId: int): bool =
  ## Returns true when a queued clear belongs to one player.
  for clear in sim.clearQueue:
    if clear.triggerPlayerId == triggerPlayerId:
      return true

proc releaseClearSpawnWaitIfDone(sim: var SimServer, triggerPlayerId: int) =
  ## Releases a player's spawn when their clear chain is done.
  if not sim.clearQueuedFor(triggerPlayerId):
    sim.releaseClearSpawnWait(triggerPlayerId)

proc startNextClear(sim: var SimServer): bool =
  while sim.clearQueue.len > 0:
    sim.activeClear = sim.clearQueue[0]
    sim.clearQueue.delete(0)
    if not sim.segmentStillFilled(sim.activeClear.segment):
      sim.releaseClearSpawnWaitIfDone(sim.activeClear.triggerPlayerId)
      continue
    sim.activeClearValid = true
    sim.clearFlashTimer = ClearFlashTicks
    sim.clearDisplayPlayerId = sim.activeClear.triggerPlayerId
    return true
  false

proc finishPendingRespawns(sim: var SimServer) =
  ## Retries all pending player respawns.
  for playerIndex in 0 ..< sim.players.len:
    if not sim.players[playerIndex].pendingSpawn:
      continue
    if sim.players[playerIndex].pendingSpawnWaitClear:
      continue
    sim.respawnPlayer(
      playerIndex,
      sim.players[playerIndex].pendingSpawnCenterX,
      sim.players[playerIndex].pendingSpawnTopY
    )

proc finalizeActiveClear(sim: var SimServer) =
  if not sim.activeClearValid:
    return

  let triggerPlayerId = sim.activeClear.triggerPlayerId
  sim.awardPendingClear(sim.activeClear)
  sim.clearSegments([sim.activeClear.segment])
  discard sim.dropUnsupportedSettledBlocks()
  sim.clearDisplayPlayerId = triggerPlayerId
  sim.activeClearValid = false
  sim.clearFlashTimer = 0

  discard sim.enqueueDetectedClears(triggerPlayerId)
  sim.releaseClearSpawnWaitIfDone(triggerPlayerId)

proc tickClearAnimation(sim: var SimServer) =
  if sim.activeClearValid:
    dec sim.clearFlashTimer
    if sim.clearFlashTimer > 0:
      return
    sim.finalizeActiveClear()

  if sim.clearQueue.len > 0:
    discard sim.startNextClear()
  elif not sim.activeClearValid:
    sim.clearDisplayPlayerId = 0

proc lockPiece(sim: var SimServer, playerIndex: int) =
  ## Settles one active piece when its current cells are still valid.
  if playerIndex < 0 or
      playerIndex >= sim.players.len or
      not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return

  let
    ignoredPlayers = [playerIndex]
    player = sim.players[playerIndex]
  if not sim.canPlaceIgnoring(
    player.cellX,
    player.cellY,
    player.pieceKind,
    player.rotation,
    ignoredPlayers
  ):
    return
  if not sim.canPlacePixelsIgnoring(
    player.cellX,
    player.pixelY,
    player.pieceKind,
    player.rotation,
    ignoredPlayers
  ):
    return

  let bounds = sim.players[playerIndex].pieceBounds()
  for cell in pieceCells(
    sim.players[playerIndex].pieceKind,
    sim.players[playerIndex].rotation
  ):
    let
      x = sim.players[playerIndex].cellX + cell.x
      y = sim.players[playerIndex].cellY + cell.y
      index = boardIndex(x, y)
    sim.settledColors[index] = sim.players[playerIndex].color
    sim.settledOwners[index] = sim.players[playerIndex].id
    sim.settledConnections[index] =
      sim.players[playerIndex].playerConnectionMask(cell)
    sim.settledCellIndices.add(index)
  sim.settledCellsDirty = true

  sim.players[playerIndex].hasPiece = false

  let
    nextCenterX = (bounds.minX + bounds.maxX) div 2
    nextTopY = bounds.minY - PieceSpawnLiftCells

  if sim.enqueueDetectedClears(sim.players[playerIndex].id):
    sim.players[playerIndex].pendingSpawn = true
    sim.players[playerIndex].pendingSpawnCenterX = nextCenterX
    sim.players[playerIndex].pendingSpawnTopY = nextTopY
    sim.players[playerIndex].pendingSpawnWaitClear = true
    if not sim.activeClearValid:
      discard sim.startNextClear()
  else:
    sim.respawnPlayer(playerIndex, nextCenterX, nextTopY)

proc applyInput(sim: var SimServer, playerIndex: int, input: InputState) =
  ## Applies one tick of player input to an active piece.
  if playerIndex < 0 or
      playerIndex >= sim.players.len or
      not sim.players[playerIndex].alive or
      not sim.players[playerIndex].hasPiece:
    return

  if sim.players[playerIndex].moveTicksX > 0:
    dec sim.players[playerIndex].moveTicksX
  if input.attack:
    discard sim.tryRotate(playerIndex)
    discard sim.tryMovePixelsY(playerIndex, CellPixels)

  let horizontal =
    (if input.left and not input.right: -1
     elif input.right and not input.left: 1
     else: 0)
  if horizontal != 0 and sim.players[playerIndex].moveTicksX == 0:
    discard sim.tryMove(playerIndex, horizontal, 0)
    sim.players[playerIndex].moveTicksX = MoveRepeatInterval

  let gravityPixels =
    if input.down:
      SoftGravityPixelsPerTick
    else:
      GravityPixelsPerTick
  discard sim.tryMovePixelsY(playerIndex, gravityPixels)

  sim.refreshLockDepth(playerIndex)
  if sim.hasStaticSupportBelow(playerIndex):
    inc sim.players[playerIndex].lockTicks
    if sim.players[playerIndex].lockTicks >= LockDelayTicks or input.select:
      sim.lockPiece(playerIndex)
  else:
    sim.players[playerIndex].lockTicks = 0

proc renderBoard(sim: var SimServer, cameraX, cameraY: int) =
  let
    startCellX = max(0, cameraX div CellPixels)
    startCellY = max(0, cameraY div CellPixels)
    endCellX = min(BoardWidthCells - 1, (cameraX + ScreenWidth - 1) div CellPixels)
    endCellY = min(BoardHeightCells - 1, (cameraY + ScreenHeight - 1) div CellPixels)

  for y in startCellY .. endCellY:
    for x in startCellX .. endCellX:
      let index = boardIndex(x, y)
      if sim.terrain[index]:
        sim.fb.putRect(x * CellPixels - cameraX, y * CellPixels - cameraY, CellPixels, CellPixels, TerrainColor)
      elif sim.settledColors[index] != 0:
        sim.fb.putRect(x * CellPixels - cameraX, y * CellPixels - cameraY, CellPixels, CellPixels, sim.settledColors[index])

proc renderActiveClear(sim: var SimServer, cameraX, cameraY: int) =
  if not sim.activeClearValid:
    return
  for x in sim.activeClear.segment.startX .. sim.activeClear.segment.endX:
    sim.fb.putRect(
      x * CellPixels - cameraX,
      sim.activeClear.segment.y * CellPixels - cameraY,
      CellPixels,
      CellPixels,
      sim.flashColor
    )

proc renderClearHud(sim: var SimServer) =
  if sim.clearDisplayPlayerId <= 0:
    return
  let
    playerNumber = sim.clearDisplayPlayerId mod 100
    popupY = 18
  var x = 0
  x += sim.fb.renderSolidText(sim.letterSprites, "P", x, popupY, sim.flashColor)
  x += sim.fb.renderSolidNumber(sim.digitSprites, playerNumber, x, popupY, sim.flashColor)
  if sim.activeClear.scoreValue > 0:
    x += 2
    x += sim.fb.renderSolidNumber(sim.digitSprites, sim.activeClear.scoreValue, x, popupY, sim.flashColor)
    if sim.activeClear.colorCount > 1:
      x += 2
      x += sim.fb.renderSolidNumber(sim.digitSprites, sim.activeClear.lineLength, x, popupY, sim.flashColor)
      x += sim.fb.renderSolidText(sim.letterSprites, "X", x, popupY, sim.flashColor)
      discard sim.fb.renderSolidNumber(sim.digitSprites, sim.activeClear.colorCount, x, popupY, sim.flashColor)

proc renderHud(sim: var SimServer, playerIndex: int) =
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return

  let player = sim.players[playerIndex]
  discard sim.fb.renderNumber(sim.digitSprites, player.score, 0, 0, showZero = false)
  sim.fb.drawPreview(player.nextKind, player.color, ScreenWidth - 8, 0)
  sim.renderClearHud()

proc render(sim: var SimServer, playerIndex: int): seq[uint8] =
  sim.fb.clearFrame(BackgroundColor)
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return sim.fb.packed

  let player = sim.players[playerIndex]
  let
    cameraX = player.cameraX
    cameraY = player.cameraY

  sim.renderBoard(cameraX, cameraY)
  for otherPlayer in sim.players:
    if otherPlayer.alive and otherPlayer.hasPiece:
      sim.fb.drawPiece(otherPlayer, cameraX, cameraY, otherPlayer.color)
  sim.renderActiveClear(cameraX, cameraY)
  sim.renderHud(playerIndex)
  sim.fb.packFramebuffer()
  sim.fb.packed

proc addRgbaSprite(
  packet: var seq[uint8],
  spriteId: int,
  sprite: RgbaSprite,
  label: string
) =
  ## Appends one RGBA sprite definition.
  packet.addSprite(spriteId, sprite.width, sprite.height, sprite.pixels, label)

proc addScorePanelDigitSprites(
  packet: var seq[uint8],
  sim: SimServer,
  state: GlobalViewerState
) =
  ## Appends stable score panel digit sprites once.
  if state.sentScorePanelDigits:
    return
  state.sentScorePanelDigits = true
  for ch in '0' .. '9':
    let digit = sim.plainTextSprite($ch, ScorePanelColor)
    packet.addRgbaSprite(
      scorePanelDigitSpriteId(ch),
      digit,
      "score digit " & $ch
    )

proc addScorePanelPlayerSprites(
  packet: var seq[uint8],
  sim: SimServer,
  state: GlobalViewerState,
  player: Player,
  name: string,
  selected: bool
) =
  ## Appends stable score panel player sprites once.
  if player.id notin state.sentScorePanelPlayers:
    state.sentScorePanelPlayers.add(player.id)
    let
      pip = buildScorePanelChipSprite(player.rgbaColor)
      label = sim.plainTextSprite(name, player.rgbaColor)
    packet.addRgbaSprite(
      scorePanelChipSpriteId(player.id),
      pip,
      "score pip " & $player.id
    )
    packet.addRgbaSprite(
      scorePanelNameSpriteId(player.id),
      label,
      "score name " & name
    )
  if selected and player.id notin state.sentSelectedScorePanelPlayers:
    state.sentSelectedScorePanelPlayers.add(player.id)
    let label = sim.plainTextSprite(name, ScorePanelSelectedColor)
    packet.addRgbaSprite(
      scorePanelNameSpriteId(player.id, selected = true),
      label,
      "selected score name " & name
    )

proc terrainRgbaColor(): RgbaColor =
  ## Returns the neutral floor color.
  RgbaColor(r: 104'u8, g: 116'u8, b: 130'u8, a: 255'u8)

proc clearRgbaColor(): RgbaColor =
  ## Returns the line-clear flash color.
  RgbaColor(r: 255'u8, g: 255'u8, b: 255'u8, a: 255'u8)

proc addBackgroundSprite(
  packet: var seq[uint8],
  state: var GlobalViewerState,
  width,
  height: int
) =
  ## Appends the black background sprite once per viewer.
  if state.sentBackgroundSprite:
    return
  state.sentBackgroundSprite = true
  let sprite = solidRgbaSprite(width, height, BackgroundRgba)
  packet.addRgbaSprite(GlobalBackgroundSpriteId, sprite, "black background")

proc ownerBlockSpriteBase(owner: int): int =
  ## Returns the first sprite id for one owner color set.
  GlobalPlayerSpriteBase + (max(1, owner) - 1) * BlockSpriteVariants

proc ownerBlockSpriteId(owner: int, mask: uint8): int =
  ## Returns the sprite id for one owner connection mask.
  owner.ownerBlockSpriteBase() + int(mask and 0x0f'u8)

proc terrainBlockSpriteId(mask: uint8): int =
  ## Returns the sprite id for one terrain connection mask.
  GlobalTerrainSpriteBase + int(mask and 0x0f'u8)

proc clearBlockSpriteId(mask: uint8): int =
  ## Returns the sprite id for one clear-flash connection mask.
  GlobalClearSpriteBase + int(mask and 0x0f'u8)

proc addBlockSpriteSet(
  packet: var seq[uint8],
  spriteBase: int,
  parts: array[BlockPartCount, RgbaSprite],
  color: RgbaColor,
  label: string
) =
  ## Appends all composite block sprites for one color.
  for mask in 0 ..< BlockSpriteVariants:
    let sprite = composeBlockSprite(parts, mask.uint8, color)
    packet.addRgbaSprite(spriteBase + mask, sprite, label & " " & $mask)

proc addTerrainBlockSprites(
  packet: var seq[uint8],
  state: var GlobalViewerState,
  parts: array[BlockPartCount, RgbaSprite]
) =
  ## Appends terrain block sprites once per viewer.
  if state.sentTerrainSprites:
    return
  state.sentTerrainSprites = true
  packet.addBlockSpriteSet(
    GlobalTerrainSpriteBase,
    parts,
    terrainRgbaColor(),
    "terrain block"
  )

proc addClearBlockSprites(
  packet: var seq[uint8],
  state: var GlobalViewerState,
  parts: array[BlockPartCount, RgbaSprite]
) =
  ## Appends clear-flash block sprites once per viewer.
  if state.sentClearSprites:
    return
  state.sentClearSprites = true
  packet.addBlockSpriteSet(
    GlobalClearSpriteBase,
    parts,
    clearRgbaColor(),
    "clear block"
  )

proc addOwnerBlockSprites(
  packet: var seq[uint8],
  ownersAdded: var seq[int],
  owner: int,
  parts: array[BlockPartCount, RgbaSprite]
) =
  ## Appends owner block sprites once per viewer.
  if owner <= 0 or owner in ownersAdded:
    return
  ownersAdded.add(owner)
  packet.addBlockSpriteSet(
    owner.ownerBlockSpriteBase(),
    parts,
    rgbaColorForPlayer(owner),
    "player block " & $owner
  )

proc paletteRgbaColor(color: uint8): RgbaColor =
  ## Returns one palette color as a true-color RGBA value.
  Palette[int(color and 0x0f'u8)]

proc blockRgbaColor(owner: int, fallbackColor: uint8): RgbaColor =
  ## Returns a true-color block color for an owner.
  if owner > 0:
    return rgbaColorForPlayer(owner)
  paletteRgbaColor(fallbackColor)

proc addObjectIfRoom(
  packet: var seq[uint8],
  objectId: var int,
  x, y, z, spriteId: int
) =
  ## Appends one object while the protocol id space has room.
  if objectId > MaxGlobalObjectId:
    return
  packet.addObject(objectId, x, y, z, GlobalLayerId, spriteId)
  inc objectId

proc addSpeechBubble(
  packet: var seq[uint8],
  sim: SimServer,
  player: Player,
  objectId: var int,
  cameraX,
  cameraY,
  z: int
) =
  ## Appends one speech bubble above a player's active piece.
  if player.message.len == 0 or player.messageTicks <= 0 or
      not player.hasPiece:
    return
  let
    alpha = uint8(max(
      1,
      min(255, player.messageTicks * 255 div ChatLifetimeTicks)
    ))
    bubble = sim.speechBubbleSprite(player.message, alpha)
    bounds = player.piecePixelBounds()
    centerX = (bounds.minX + bounds.maxX) div 2
    nameText = player.name.cleanNameLabel()
    nameLift =
      if nameText.len > 0:
        sim.textFont.height + 1 + NameGapY
      else:
        0
    x = centerX - cameraX - bubble.width div 2
    y = bounds.minY - cameraY - nameLift - bubble.height - ChatGapY
    spriteId = GlobalChatSpriteBase + (player.id mod 1000)
  packet.addRgbaSprite(spriteId, bubble, "chat " & player.message)
  packet.addObjectIfRoom(objectId, x, y, z, spriteId)

proc addNameLabel(
  packet: var seq[uint8],
  sim: SimServer,
  state: GlobalViewerState,
  player: Player,
  objectId: var int,
  cameraX,
  cameraY,
  viewportWidth,
  z: int
) =
  ## Appends one player name label above an active piece.
  if not player.hasPiece:
    return
  let text = player.name.cleanNameLabel()
  if text.len == 0:
    return
  if player.id notin state.sentNameLabels:
    state.sentNameLabels.add(player.id)
    let sprite = sim.textLineSprite(
      text,
      RgbaColor(r: 255'u8, g: 255'u8, b: 255'u8, a: 255'u8)
    )
    packet.addRgbaSprite(
      GlobalNameSpriteBase + (player.id mod 1000),
      sprite,
      "name " & text
    )
  let
    bounds = player.piecePixelBounds()
    centerX = (bounds.minX + bounds.maxX) div 2
    spriteWidth = sim.chatTextWidth(text) + 1
    spriteHeight = sim.textFont.height + 1
  var
    x = centerX - cameraX - spriteWidth div 2
    y = bounds.minY - cameraY - spriteHeight - NameGapY
  x = max(0, min(viewportWidth - spriteWidth, x))
  let spriteId = GlobalNameSpriteBase + (player.id mod 1000)
  packet.addObjectIfRoom(objectId, x, y, z, spriteId)

proc addGlobalScorePanel(
  packet: var seq[uint8],
  sim: SimServer,
  state: var GlobalViewerState,
  selectedPlayerIndex = -1
) =
  ## Appends the global score panel objects.
  if sim.players.len == 0:
    return
  let order = sim.scorePanelPlayerOrder()
  let
    rowHeight = sim.scorePanelRowHeight()
    scoreColumnWidth = sim.scorePanelScoreWidth(order)
    nameColumnWidth = sim.scorePanelNameWidth(order)
    scoreX = ScorePanelPipSize + ScorePanelPipGapX
    nameX = sim.scorePanelNameX(order)
    panelWidth = max(1, nameX + nameColumnWidth)
    panelHeight = max(1, min(order.len, ScorePanelMaxRows) * rowHeight)
  packet.addLayer(
    GlobalScorePanelLayerId,
    GlobalTopLeftLayerType,
    GlobalUiFlag
  )
  packet.addViewport(
    GlobalScorePanelLayerId,
    panelWidth,
    panelHeight
  )
  packet.addScorePanelDigitSprites(sim, state)
  for i, playerIndex in order:
    if i >= ScorePanelMaxRows:
      break
    let player = sim.players[playerIndex]
    let
      rowY = i * rowHeight
      pipY = rowY + (rowHeight - ScorePanelPipSize) div 2
      scoreText = scorePanelScoreText(player.score)
      scoreWidth = sim.textFont.textWidth(scoreText)
      alignedScoreX = scoreX + max(0, scoreColumnWidth - scoreWidth)
      name = player.scorePanelNameText()
      selected = playerIndex == selectedPlayerIndex
    packet.addScorePanelPlayerSprites(
      sim,
      state,
      player,
      name,
      selected
    )
    packet.addObject(
      scorePanelChipObjectId(i),
      0,
      pipY,
      high(int16),
      GlobalScorePanelLayerId,
      scorePanelChipSpriteId(player.id)
    )
    packet.addObject(
      scorePanelNameObjectId(i),
      nameX,
      rowY,
      high(int16),
      GlobalScorePanelLayerId,
      scorePanelNameSpriteId(player.id, selected)
    )
    var digitX = alignedScoreX
    for j, ch in scoreText:
      if j >= ScorePanelMaxScoreChars:
        break
      if ch < '0' or ch > '9':
        continue
      packet.addObject(
        scorePanelDigitObjectId(i, j),
        digitX,
        rowY,
        high(int16),
        GlobalScorePanelLayerId,
        scorePanelDigitSpriteId(ch)
      )
      digitX += sim.textFont.glyphAdvance(ch)

proc fillBarRect(
  bar: var RgbaSprite,
  x, y, w, h: int,
  color: RgbaColor
) =
  ## Fills one rectangle inside the replay control bar sprite.
  for py in y ..< min(y + h, bar.height):
    for px in x ..< min(x + w, bar.width):
      bar.putRgbaSpritePixel(px, py, color)

proc replayBarKey(
  tick, maxTick: int,
  playing, looping: bool,
  speedIndex: int
): int =
  ## Returns a change key for the rendered replay control bar.
  let knobX =
    if maxTick > 0:
      clamp(tick * (ReplayScrubberWidth - 1) div maxTick,
        0, ReplayScrubberWidth - 1)
    else:
      0
  knobX or (speedIndex shl 8) or
    (ord(playing) shl 12) or (ord(looping) shl 13)

proc buildReplayControlsSprite(
  sim: SimServer,
  tick, maxTick: int,
  playing, looping: bool,
  speedIndex: int
): RgbaSprite =
  ## Builds the replay transport controls and scrubber bar sprite.
  result = newRgbaSprite(ReplayControlsWidth, ReplayControlsHeight)
  let
    backdrop = RgbaColor(r: 12'u8, g: 12'u8, b: 20'u8, a: 200'u8)
    dim = RgbaColor(r: 130'u8, g: 130'u8, b: 140'u8, a: 255'u8)
    bright = RgbaColor(r: 255'u8, g: 255'u8, b: 255'u8, a: 255'u8)
    accent = RgbaColor(r: 255'u8, g: 200'u8, b: 80'u8, a: 255'u8)
  result.fillBarRect(0, 0, ReplayControlsWidth, ReplayControlsHeight, backdrop)

  sim.blitChatText(result, "|<", 4, ReplayButtonTextY, bright)
  sim.blitChatText(result, "<<", 20, ReplayButtonTextY, bright)
  if playing:
    sim.blitChatText(result, "||", 36, ReplayButtonTextY, accent)
  else:
    sim.blitChatText(result, "|>", 36, ReplayButtonTextY, bright)
  sim.blitChatText(result, ">>", 52, ReplayButtonTextY, bright)
  sim.blitChatText(result, ">|", 68, ReplayButtonTextY, bright)

  let speedTexts = ["1x", "2x", "3x", "4x", "8x", "16x"]
  for i, text in speedTexts:
    sim.blitChatText(
      result,
      text,
      ReplaySpeedTextX + i * 12,
      ReplayButtonTextY,
      if i == speedIndex: accent else: dim
    )

  let knobX =
    if maxTick > 0:
      ReplayScrubberX + clamp(
        tick * (ReplayScrubberWidth - 1) div maxTick,
        0,
        ReplayScrubberWidth - 1
      )
    else:
      ReplayScrubberX
  result.fillBarRect(
    ReplayScrubberX,
    ReplayScrubberTrackY,
    ReplayScrubberWidth,
    2,
    dim
  )
  if knobX > ReplayScrubberX:
    result.fillBarRect(
      ReplayScrubberX,
      ReplayScrubberTrackY,
      knobX - ReplayScrubberX,
      2,
      bright
    )
  result.fillBarRect(
    max(ReplayScrubberX, knobX - 1),
    ReplayScrubberY,
    3,
    ReplayScrubberHeight,
    accent
  )

proc replayControlCommandAt(x, y: int): char =
  ## Returns the replay command for one control bar button click.
  if y < 0 or y >= ReplayButtonRowHeight:
    return '\0'
  case x
  of 0 .. 15: ','
  of 16 .. 31: 'B'
  of 32 .. 47: ' '
  of 48 .. 63: '.'
  of 64 .. 79: 'e'
  of 86 .. 97: '1'
  of 98 .. 109: '2'
  of 110 .. 121: '3'
  of 122 .. 133: '4'
  of 134 .. 145: '8'
  of 146 .. 159: '6'
  else: '\0'

proc replayScrubTickAt(
  x, y, maxTick: int,
  requireInside = true
): int =
  ## Returns the replay tick under the scrubber pointer.
  if maxTick <= 0:
    return -1
  if requireInside and (
      y < ReplayScrubberY or y >= ReplayControlsHeight or
      x < ReplayScrubberX or x >= ReplayScrubberX + ReplayScrubberWidth
    ):
    return -1
  let localX = clamp(x - ReplayScrubberX, 0, ReplayScrubberWidth - 1)
  clamp(localX * maxTick div (ReplayScrubberWidth - 1), 0, maxTick)

proc addReplayControls(
  packet: var seq[uint8],
  state: GlobalViewerState,
  bar: RgbaSprite,
  barKey: int
) =
  ## Appends the replay control bar layer to one global packet.
  packet.addLayer(
    GlobalReplayControlsLayerId,
    GlobalBottomCenterLayerType,
    GlobalUiFlag
  )
  packet.addViewport(
    GlobalReplayControlsLayerId,
    ReplayControlsWidth,
    ReplayControlsHeight
  )
  if state.lastReplayBarKey != barKey:
    state.lastReplayBarKey = barKey
    packet.addRgbaSprite(ReplayControlsSpriteId, bar, "replay controls")
  packet.addObject(
    ReplayControlsObjectId,
    0,
    0,
    high(int16),
    GlobalReplayControlsLayerId,
    ReplayControlsSpriteId
  )

proc applyReplayViewerMouse(state: GlobalViewerState, data: string) =
  ## Tracks viewer mouse state for the replay control bar.
  for item in data.parseSpriteClientMessages():
    case item.kind
    of SpriteClientMouseMoveMessage:
      state.mouseX = item.x
      state.mouseY = item.y
      state.mouseLayer =
        if item.hasLayer:
          item.layer
        else:
          GlobalLayerId
    of SpriteClientMouseButtonMessage:
      if item.button == 1'u8:
        if item.down:
          state.mouseDown = true
          state.mousePressed = true
        else:
          state.mouseDown = false
          state.mouseReleased = true
    else:
      discard

proc putRgbaColorPixel(
  pixels: var seq[uint8],
  pixelIndex: int,
  color: RgbaColor
) =
  ## Writes one true-color RGBA pixel.
  let offset = pixelIndex * 4
  pixels[offset] = color.r
  pixels[offset + 1] = color.g
  pixels[offset + 2] = color.b
  pixels[offset + 3] = color.a

proc rgbaFromPackedFrame(frame: openArray[uint8]): seq[uint8] =
  ## Converts one packed palette framebuffer to RGBA pixels.
  result = newSeq[uint8](ScreenWidth * ScreenHeight * 4)
  var pixelIndex = 0
  for byte in frame:
    for packedIndex in 0 .. 1:
      let colorIndex =
        if packedIndex == 0:
          byte and 0x0f'u8
        else:
          byte shr 4
      let
        color = Palette[int(colorIndex)]
        offset = pixelIndex * 4
      result[offset] = color.r
      result[offset + 1] = color.g
      result[offset + 2] = color.b
      result[offset + 3] = color.a
      inc pixelIndex

proc packedFramePixel(frame: openArray[uint8], x, y: int): uint8 =
  ## Returns one palette index from a packed framebuffer.
  if x < 0 or y < 0 or x >= ScreenWidth or y >= ScreenHeight:
    return 0
  let
    pixelIndex = y * ScreenWidth + x
    value = frame[pixelIndex div 2]
  if (pixelIndex and 1) == 0:
    value and 0x0f'u8
  else:
    value shr 4

proc putRgbaRectMasked(
  pixels: var seq[uint8],
  frame: openArray[uint8],
  x, y, w, h: int,
  sourceColor: uint8,
  color: RgbaColor
) =
  ## Recolors a packed-frame rectangle where the source color matches.
  for py in 0 ..< h:
    let sy = y + py
    if sy < 0 or sy >= ScreenHeight:
      continue
    for px in 0 ..< w:
      let sx = x + px
      if sx < 0 or sx >= ScreenWidth:
        continue
      if frame.packedFramePixel(sx, sy) == sourceColor:
        pixels.putRgbaColorPixel(sy * ScreenWidth + sx, color)

proc overlayRgbaBoardBlocks(
  sim: SimServer,
  pixels: var seq[uint8],
  frame: openArray[uint8],
  cameraX, cameraY: int
) =
  ## Recolors visible settled blocks with true-color owner colors.
  let
    startCellX = max(0, cameraX div CellPixels)
    startCellY = max(0, cameraY div CellPixels)
    endCellX = min(BoardWidthCells - 1, (cameraX + ScreenWidth - 1) div CellPixels)
    endCellY = min(BoardHeightCells - 1, (cameraY + ScreenHeight - 1) div CellPixels)
  for y in startCellY .. endCellY:
    for x in startCellX .. endCellX:
      let
        index = boardIndex(x, y)
        sourceColor = sim.settledColors[index]
      if sourceColor == 0:
        continue
      pixels.putRgbaRectMasked(
        frame,
        x * CellPixels - cameraX,
        y * CellPixels - cameraY,
        CellPixels,
        CellPixels,
        sourceColor,
        blockRgbaColor(sim.settledOwners[index], sourceColor)
      )

proc overlayRgbaPiece(
  pixels: var seq[uint8],
  frame: openArray[uint8],
  player: Player,
  cameraX, cameraY: int
) =
  ## Recolors one visible active piece with its true-color player color.
  for cell in pieceCells(player.pieceKind, player.rotation):
    let
      screenX = (player.cellX + cell.x) * CellPixels - cameraX
      screenY = player.pieceCellPixelY(cell) - cameraY
    pixels.putRgbaRectMasked(
      frame,
      screenX,
      screenY,
      CellPixels,
      CellPixels,
      player.color,
      player.rgbaColor
    )

proc overlayRgbaPreview(
  pixels: var seq[uint8],
  frame: openArray[uint8],
  kind: PieceKind,
  sourceColor: uint8,
  color: RgbaColor,
  screenX, screenY: int
) =
  ## Recolors the next-piece preview with its true-color player color.
  let previewPlayer = Player(pieceKind: kind, rotation: 0, cellX: 0, cellY: 0)
  for cell in pieceCells(previewPlayer.pieceKind, previewPlayer.rotation):
    pixels.putRgbaRectMasked(
      frame,
      screenX + cell.x * CellPixels,
      screenY + cell.y * CellPixels,
      CellPixels,
      CellPixels,
      sourceColor,
      color
    )

proc renderSpriteFrame(sim: var SimServer, playerIndex: int): seq[uint8] =
  ## Renders a true-color sprite-protocol player frame.
  let frame = sim.render(playerIndex)
  result = rgbaFromPackedFrame(frame)
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return
  let player = sim.players[playerIndex]
  let
    cameraX = player.cameraX
    cameraY = player.cameraY
  sim.overlayRgbaBoardBlocks(result, frame, cameraX, cameraY)
  for otherPlayer in sim.players:
    if otherPlayer.alive and otherPlayer.hasPiece:
      result.overlayRgbaPiece(frame, otherPlayer, cameraX, cameraY)
  result.overlayRgbaPreview(
    frame,
    player.nextKind,
    player.color,
    player.rgbaColor,
    ScreenWidth - 8,
    0
  )

proc selectedGlobalPlayerIndex(
  state: GlobalViewerState,
  sim: SimServer
): int =
  ## Returns the selected player index clamped to live players.
  if state == nil or state.selectedPlayerIndex < 0:
    return -1
  if state.selectedPlayerIndex >= sim.players.len:
    return -1
  state.selectedPlayerIndex

proc applyPendingScorePanelClick(state: GlobalViewerState, sim: SimServer) =
  ## Applies one pending score panel click to the selected player.
  if state == nil or not state.pendingScorePanelClick:
    return
  let clickedPlayer = sim.scorePanelPlayerAt(
    state.pendingScorePanelClickX,
    state.pendingScorePanelClickY
  )
  if clickedPlayer >= 0:
    state.selectedPlayerIndex =
      if state.selectedPlayerIndex == clickedPlayer:
        -1
      else:
        clickedPlayer
  state.pendingScorePanelClick = false

proc buildGlobalFramePacket(
  sim: var SimServer,
  playerIndex: int,
  state: GlobalViewerState,
  nextState: var GlobalViewerState
): seq[uint8] =
  ## Builds one global protocol packet for a sprite-object player frame.
  nextState = viewerState(state)
  if not nextState.initialized:
    result.addViewport(
      GlobalLayerId,
      PlayerViewportWidth,
      PlayerViewportHeight
    )
    result.addLayer(GlobalLayerId, GlobalMapLayerType, GlobalZoomableFlag)
    nextState.initialized = true
  result.addBackgroundSprite(
    nextState,
    PlayerViewportWidth,
    PlayerViewportHeight
  )
  result.addTerrainBlockSprites(nextState, sim.blockParts)
  result.addClearObjects()
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return
  let player = sim.players[playerIndex]
  if not player.alive:
    return
  let
    cameraX = player.cameraX
    cameraY = player.cameraY
    startCellX = max(0, cameraX div CellPixels)
    startCellY = max(0, cameraY div CellPixels)
    endCellX = min(
      BoardWidthCells - 1,
      (cameraX + PlayerViewportWidth - 1) div CellPixels
    )
    endCellY = min(
      BoardHeightCells - 1,
      (cameraY + PlayerViewportHeight - 1) div CellPixels
    )
  var objectId = GlobalFrameObjectBase
  result.addObjectIfRoom(objectId, 0, 0, -10, GlobalBackgroundSpriteId)

  for y in startCellY .. endCellY:
    for x in startCellX .. endCellX:
      let index = boardIndex(x, y)
      if sim.terrain[index]:
        result.addObjectIfRoom(
          objectId,
          x * CellPixels - cameraX,
          y * CellPixels - cameraY,
          0,
          terrainBlockSpriteId(terrainConnectionMask(x))
        )
      elif sim.settledColors[index] != 0:
        let owner = sim.settledOwners[index]
        result.addOwnerBlockSprites(
          nextState.sentOwners,
          owner,
          sim.blockParts
        )
        result.addObjectIfRoom(
          objectId,
          x * CellPixels - cameraX,
          y * CellPixels - cameraY,
          1,
          ownerBlockSpriteId(owner, sim.settledConnections[index])
        )

  if sim.activeClearValid:
    result.addClearBlockSprites(nextState, sim.blockParts)
    for x in sim.activeClear.segment.startX .. sim.activeClear.segment.endX:
      let
        index = boardIndex(x, sim.activeClear.segment.y)
        mask =
          if inBoardBounds(x, sim.activeClear.segment.y):
            sim.settledConnections[index]
          else:
            0'u8
      result.addObjectIfRoom(
        objectId,
        x * CellPixels - cameraX,
        sim.activeClear.segment.y * CellPixels - cameraY,
        2,
        clearBlockSpriteId(mask)
      )

  for otherPlayer in sim.players:
    if not otherPlayer.alive or not otherPlayer.hasPiece:
      continue
    result.addOwnerBlockSprites(
      nextState.sentOwners,
      otherPlayer.id,
      sim.blockParts
    )
    for cell in pieceCells(otherPlayer.pieceKind, otherPlayer.rotation):
      result.addObjectIfRoom(
        objectId,
        (otherPlayer.cellX + cell.x) * CellPixels - cameraX,
        otherPlayer.pieceCellPixelY(cell) - cameraY,
        3,
        ownerBlockSpriteId(
          otherPlayer.id,
          otherPlayer.playerConnectionMask(cell)
        )
      )

  for otherPlayer in sim.players:
    if not otherPlayer.alive:
      continue
    addNameLabel(
      result,
      sim,
      nextState,
      otherPlayer,
      objectId,
      cameraX,
      cameraY,
      PlayerViewportWidth,
      5
    )
    addSpeechBubble(
      result,
      sim,
      otherPlayer,
      objectId,
      cameraX,
      cameraY,
      5
    )

  result.addOwnerBlockSprites(nextState.sentOwners, player.id, sim.blockParts)
  for cell in pieceCells(player.nextKind, 0):
    result.addObjectIfRoom(
      objectId,
      PreviewX + cell.x * CellPixels,
      cell.y * CellPixels,
      4,
      ownerBlockSpriteId(player.id, pieceConnectionMask(player.nextKind, 0, cell))
    )

proc buildPlayerViewerPacket(
  sim: var SimServer,
  playerIndex: int,
  state: GlobalViewerState,
  nextState: var GlobalViewerState
): seq[uint8] =
  ## Builds one player POV packet with the score panel overlay.
  result = sim.buildGlobalFramePacket(playerIndex, state, nextState)
  if playerIndex >= 0 and playerIndex < sim.players.len:
    result.addGlobalScorePanel(sim, nextState, playerIndex)

proc buildGlobalMapPacket(
  sim: var SimServer,
  state: GlobalViewerState,
  nextState: var GlobalViewerState,
  selectedPlayerIndex = -1
): seq[uint8] =
  ## Builds one global protocol packet for the full board overview.
  nextState = viewerState(state)
  if not nextState.initialized:
    result.addViewport(GlobalLayerId, GlobalMapWidth, GlobalMapHeight)
    result.addLayer(GlobalLayerId, GlobalMapLayerType, GlobalZoomableFlag)
    nextState.initialized = true
  result.addTerrainBlockSprites(nextState, sim.blockParts)
  result.addClearObjects()
  if sim.activeClearValid:
    result.addClearBlockSprites(nextState, sim.blockParts)

  var objectId = GlobalBlockObjectBase
  result.addGlobalScorePanel(sim, nextState, selectedPlayerIndex)
  if sim.settledCellsDirty:
    sim.rebuildSettledCellIndices()
  for x in 0 ..< BoardWidthCells:
    result.addObjectIfRoom(
      objectId,
      x * CellPixels,
      BaseTerrainY * CellPixels,
      0,
      terrainBlockSpriteId(terrainConnectionMask(x))
    )
  for index in sim.settledCellIndices:
    let color = sim.settledColors[index]
    if color == 0:
      continue
    let
      x = index mod BoardWidthCells
      y = index div BoardWidthCells
      owner = sim.settledOwners[index]
    result.addOwnerBlockSprites(
      nextState.sentOwners,
      owner,
      sim.blockParts
    )
    result.addObjectIfRoom(
      objectId,
      x * CellPixels,
      y * CellPixels,
      1,
      ownerBlockSpriteId(owner, sim.settledConnections[index])
    )

  if sim.activeClearValid:
    for x in sim.activeClear.segment.startX .. sim.activeClear.segment.endX:
      let
        index = boardIndex(x, sim.activeClear.segment.y)
        mask = sim.settledConnections[index]
      result.addObjectIfRoom(
        objectId,
        x * CellPixels,
        sim.activeClear.segment.y * CellPixels,
        2,
        clearBlockSpriteId(mask)
      )

  for player in sim.players:
    if not player.alive or not player.hasPiece:
      continue
    result.addOwnerBlockSprites(nextState.sentOwners, player.id, sim.blockParts)
    for cell in pieceCells(player.pieceKind, player.rotation):
      result.addObjectIfRoom(
        objectId,
        (player.cellX + cell.x) * CellPixels,
        player.pieceCellPixelY(cell),
        3,
        ownerBlockSpriteId(player.id, player.playerConnectionMask(cell))
      )

  for player in sim.players:
    if not player.alive:
      continue
    addNameLabel(
      result,
      sim,
      nextState,
      player,
      objectId,
      0,
      0,
      GlobalMapWidth,
      5
    )
    addSpeechBubble(result, sim, player, objectId, 0, 0, 5)

proc buildGlobalViewerPacket(
  sim: var SimServer,
  state: GlobalViewerState,
  nextState: var GlobalViewerState
): seq[uint8] =
  ## Builds the global map or the selected player's point of view.
  nextState = viewerState(state)
  let previousViewPlayerIndex = nextState.viewPlayerIndex
  nextState.applyPendingScorePanelClick(sim)
  let selectedPlayerIndex = nextState.selectedGlobalPlayerIndex(sim)
  nextState.selectedPlayerIndex = selectedPlayerIndex
  if previousViewPlayerIndex != selectedPlayerIndex:
    nextState.resetProtocolState()
  nextState.viewPlayerIndex = selectedPlayerIndex
  if selectedPlayerIndex >= 0:
    var frameState: GlobalViewerState
    result = sim.buildGlobalFramePacket(
      selectedPlayerIndex,
      nextState,
      frameState
    )
    nextState = frameState
    result.addGlobalScorePanel(sim, nextState, selectedPlayerIndex)
  else:
    var mapState: GlobalViewerState
    result = sim.buildGlobalMapPacket(
      nextState,
      mapState,
      selectedPlayerIndex
    )
    nextState = mapState

proc buildRewardPacket(sim: SimServer): string =
  for player in sim.players:
    result.add("reward ")
    result.add(player.name)
    result.add(" ")
    result.add($player.score)
    result.add("\n")

proc playerResultsJson(sim: SimServer, slotCount: int): string =
  ## Builds the current per-player result JSON, padded so every
  ## declared player slot has a row even when a player never joined.
  var
    names = newJArray()
    scores = newJArray()
    alive = newJArray()
  for player in sim.players:
    names.add(%player.name)
    scores.add(%player.score)
    alive.add(%true)
  for _ in sim.players.len ..< slotCount:
    names.add(%"")
    scores.add(%0)
    alive.add(%false)
  let results = %*{
    "names": names,
    "scores": scores,
    "alive": alive
  }
  $results

proc writeScoresIfChanged(
  sim: SimServer,
  lastScores: var string,
  runtimeConfig: RuntimeConfig,
  slotCount: int
) =
  ## Writes scores when the serialized result changed.
  if runtimeConfig.resultsUri.len == 0:
    return
  let scores = sim.playerResultsJson(slotCount)
  if scores == lastScores:
    return
  runtimeConfig.writeResults(scores & "\n")
  lastScores = scores

proc keepPlayersAlive(sim: var SimServer) =
  ## Restores player liveness because Infinite Blocks has no death state.
  for player in sim.players.mitems:
    player.alive = true

proc tickChatMessages(sim: var SimServer) =
  ## Fades and clears player speech bubbles.
  for player in sim.players.mitems:
    if player.messageTicks > 0:
      dec player.messageTicks
    if player.messageTicks <= 0:
      player.messageTicks = 0
      player.message.setLen(0)

proc step*(sim: var SimServer, inputs: openArray[InputState]) =
  sim.keepPlayersAlive()
  sim.tickChatMessages()
  sim.tickClearAnimation()
  sim.finishPendingRespawns()

  for playerIndex in 0 ..< sim.players.len:
    let input =
      if playerIndex < inputs.len: inputs[playerIndex]
      else: InputState()
    sim.applyInput(playerIndex, input)
    if playerIndex < sim.players.len and sim.players[playerIndex].alive and sim.players[playerIndex].hasPiece:
      sim.players[playerIndex].updateCameraForPlayer()

  inc sim.tickCount

proc mixHash(hash: var uint64, value: uint64) =
  ## Mixes one value into a running FNV-1a style hash.
  hash = (hash xor value) * 1099511628211'u64

proc mixHashInt(hash: var uint64, value: int) =
  ## Mixes one integer into a running hash.
  hash.mixHash(cast[uint64](int64(value)))

proc gameHash*(sim: SimServer): uint64 =
  ## Returns a deterministic hash of gameplay state.
  result = 14695981039346656037'u64
  result.mixHashInt(sim.tickCount)
  result.mixHashInt(sim.nextPlayerId)
  result.mixHashInt(sim.players.len)
  for player in sim.players:
    result.mixHashInt(player.id)
    result.mixHashInt(player.score)
    result.mixHashInt(ord(player.alive))
    result.mixHashInt(ord(player.hasPiece))
    result.mixHashInt(ord(player.pieceKind))
    result.mixHashInt(ord(player.nextKind))
    result.mixHashInt(player.rotation)
    result.mixHashInt(player.cellX)
    result.mixHashInt(player.cellY)
    result.mixHashInt(player.pixelY)
    result.mixHashInt(player.moveTicksX)
    result.mixHashInt(player.lockTicks)
    result.mixHashInt(player.deepestCellY)
    result.mixHashInt(player.cameraX)
    result.mixHashInt(player.cameraY)
    result.mixHashInt(player.pendingSpawnCenterX)
    result.mixHashInt(player.pendingSpawnTopY)
    result.mixHashInt(ord(player.pendingSpawn))
    result.mixHashInt(ord(player.pendingSpawnWaitClear))
    result.mixHashInt(player.messageTicks)
    result.mixHashInt(player.message.len)
  for color in sim.settledColors:
    result.mixHashInt(int(color))
  for owner in sim.settledOwners:
    result.mixHashInt(owner)
  for connection in sim.settledConnections:
    result.mixHashInt(int(connection))
  result.mixHashInt(sim.clearQueue.len)
  for clear in sim.clearQueue:
    result.mixHashInt(clear.segment.y)
    result.mixHashInt(clear.segment.startX)
    result.mixHashInt(clear.segment.endX)
    result.mixHashInt(clear.triggerPlayerId)
    result.mixHashInt(clear.lineLength)
    result.mixHashInt(clear.colorCount)
    result.mixHashInt(clear.scoreValue)
  result.mixHashInt(ord(sim.activeClearValid))
  result.mixHashInt(sim.activeClear.segment.y)
  result.mixHashInt(sim.activeClear.segment.startX)
  result.mixHashInt(sim.activeClear.segment.endX)
  result.mixHashInt(sim.activeClear.triggerPlayerId)
  result.mixHashInt(sim.activeClear.scoreValue)
  result.mixHashInt(sim.clearFlashTimer)
  result.mixHashInt(sim.clearDisplayPlayerId)
  result.mixHashInt(int(sim.flashColor))

proc applyPlayerChat*(sim: var SimServer, playerIndex: int, message: string) =
  ## Shows one chat message above a player's head.
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return
  sim.players[playerIndex].message = message
  sim.players[playerIndex].messageTicks = ChatLifetimeTicks

proc removePlayerAt*(sim: var SimServer, playerIndex: int) =
  ## Removes one player from the simulation, compacting indices.
  if playerIndex < 0 or playerIndex >= sim.players.len:
    return
  sim.players.delete(playerIndex)

proc applyReplayEvents(replay: var ReplayPlayer, sim: var SimServer) =
  ## Applies replay leaves, joins, inputs, and chats for the current tick.
  let time = tickTime(sim.tickCount)
  while replay.leaveIndex < replay.data.leaves.len and
      replay.data.leaves[replay.leaveIndex].time <= time:
    let leave = replay.data.leaves[replay.leaveIndex]
    if int(leave.player) < 0 or int(leave.player) >= sim.players.len:
      raise newException(ReplayError, "Replay player leave is invalid")
    sim.removePlayerAt(int(leave.player))
    if int(leave.player) < replay.masks.len:
      replay.masks.delete(int(leave.player))
    if int(leave.player) < replay.prevMasks.len:
      replay.prevMasks.delete(int(leave.player))
    inc replay.leaveIndex

  while replay.joinIndex < replay.data.joins.len and
      replay.data.joins[replay.joinIndex].time <= time:
    let join = replay.data.joins[replay.joinIndex]
    if int(join.player) != sim.players.len:
      raise newException(ReplayError, "Replay player join order is invalid")
    if sim.addPlayer(join.name) != int(join.player):
      raise newException(ReplayError, "Replay player join was rejected")
    replay.ensureReplayPlayer(int(join.player))
    inc replay.joinIndex

  while replay.inputIndex < replay.data.inputs.len and
      replay.data.inputs[replay.inputIndex].time <= time:
    let input = replay.data.inputs[replay.inputIndex]
    replay.ensureReplayPlayer(int(input.player))
    replay.masks[int(input.player)] = input.keys
    inc replay.inputIndex

  while replay.chatIndex < replay.data.chats.len and
      replay.data.chats[replay.chatIndex].time <= time:
    let chat = replay.data.chats[replay.chatIndex]
    sim.applyPlayerChat(int(chat.player), chat.message)
    inc replay.chatIndex

proc checkReplayHash(replay: var ReplayPlayer, sim: SimServer) =
  ## Checks the recorded hash for the current tick, leniently.
  if replay.hashValidationFailed:
    if sim.tickCount >= replay.replayMaxTick():
      replay.playing = false
    return
  if replay.hashIndex >= replay.data.hashes.len:
    replay.playing = false
    return
  let expected = replay.data.hashes[replay.hashIndex]
  if int(expected.tick) < sim.tickCount:
    echo "Replay hash tick is missing at tick ", sim.tickCount, "."
    replay.hashValidationFailed = true
    replay.hashMismatchTick = sim.tickCount
    return
  if int(expected.tick) > sim.tickCount:
    return
  let hash = sim.gameHash()
  if hash != expected.hash:
    echo "Replay hash mismatch at tick ", sim.tickCount,
      "; expected ", expected.hash, ", got ", hash, "."
    replay.hashValidationFailed = true
    replay.hashMismatchTick = sim.tickCount
    return
  inc replay.hashIndex

proc stepReplay*(replay: var ReplayPlayer, sim: var SimServer) =
  ## Advances replay playback by one simulation tick, reproducing the
  ## live loop's rising-edge attack detection from held input masks.
  replay.applyReplayEvents(sim)
  var inputs = newSeq[InputState](sim.players.len)
  for playerIndex in 0 ..< sim.players.len:
    replay.ensureReplayPlayer(playerIndex)
    let
      mask = replay.masks[playerIndex]
      previousMask = replay.prevMasks[playerIndex]
    inputs[playerIndex] = decodeInputMask(mask)
    inputs[playerIndex].attack =
      (mask and ButtonA) != 0 and (previousMask and ButtonA) == 0
    replay.prevMasks[playerIndex] = mask
  sim.step(inputs)
  replay.checkReplayHash(sim)

type
  SimCore = object
    ## The deterministic simulation state captured by seek keyframes.
    tickCount: int
    players: seq[Player]
    settledColors: seq[uint8]
    settledOwners: seq[int]
    settledConnections: seq[uint8]
    settledCellIndices: seq[int]
    settledCellsDirty: bool
    terrain: seq[bool]
    rng: Rand
    nextPlayerId: int
    flashColor: uint8
    clearQueue: seq[PendingClear]
    activeClear: PendingClear
    activeClearValid: bool
    clearFlashTimer: int
    clearDisplayPlayerId: int

  ReplayKeyframe* = object
    tick*: int
    core: SimCore
    joinIndex: int
    leaveIndex: int
    inputIndex: int
    chatIndex: int
    hashIndex: int
    masks: seq[uint8]
    prevMasks: seq[uint8]
    hashValidationFailed: bool
    hashMismatchTick: int

proc saveSimCore(sim: SimServer): SimCore =
  ## Captures the deterministic simulation state for one keyframe.
  SimCore(
    tickCount: sim.tickCount,
    players: sim.players,
    settledColors: sim.settledColors,
    settledOwners: sim.settledOwners,
    settledConnections: sim.settledConnections,
    settledCellIndices: sim.settledCellIndices,
    settledCellsDirty: sim.settledCellsDirty,
    terrain: sim.terrain,
    rng: sim.rng,
    nextPlayerId: sim.nextPlayerId,
    flashColor: sim.flashColor,
    clearQueue: sim.clearQueue,
    activeClear: sim.activeClear,
    activeClearValid: sim.activeClearValid,
    clearFlashTimer: sim.clearFlashTimer,
    clearDisplayPlayerId: sim.clearDisplayPlayerId
  )

proc restoreSimCore(sim: var SimServer, core: SimCore) =
  ## Restores keyframe state onto a live sim, keeping render resources.
  sim.tickCount = core.tickCount
  sim.players = core.players
  sim.settledColors = core.settledColors
  sim.settledOwners = core.settledOwners
  sim.settledConnections = core.settledConnections
  sim.settledCellIndices = core.settledCellIndices
  sim.settledCellsDirty = core.settledCellsDirty
  sim.terrain = core.terrain
  sim.rng = core.rng
  sim.nextPlayerId = core.nextPlayerId
  sim.flashColor = core.flashColor
  sim.clearQueue = core.clearQueue
  sim.activeClear = core.activeClear
  sim.activeClearValid = core.activeClearValid
  sim.clearFlashTimer = core.clearFlashTimer
  sim.clearDisplayPlayerId = core.clearDisplayPlayerId

proc saveReplayKeyframe(
  replay: ReplayPlayer,
  sim: SimServer
): ReplayKeyframe =
  ## Builds one replay keyframe from the current playback state.
  ReplayKeyframe(
    tick: sim.tickCount,
    core: sim.saveSimCore(),
    joinIndex: replay.joinIndex,
    leaveIndex: replay.leaveIndex,
    inputIndex: replay.inputIndex,
    chatIndex: replay.chatIndex,
    hashIndex: replay.hashIndex,
    masks: replay.masks,
    prevMasks: replay.prevMasks,
    hashValidationFailed: replay.hashValidationFailed,
    hashMismatchTick: replay.hashMismatchTick
  )

proc restoreReplayKeyframe(
  replay: var ReplayPlayer,
  sim: var SimServer,
  keyframe: ReplayKeyframe
) =
  ## Restores playback state from one replay keyframe.
  sim.restoreSimCore(keyframe.core)
  replay.joinIndex = keyframe.joinIndex
  replay.leaveIndex = keyframe.leaveIndex
  replay.inputIndex = keyframe.inputIndex
  replay.chatIndex = keyframe.chatIndex
  replay.hashIndex = keyframe.hashIndex
  replay.masks = keyframe.masks
  replay.prevMasks = keyframe.prevMasks
  replay.hashValidationFailed = keyframe.hashValidationFailed
  replay.hashMismatchTick = keyframe.hashMismatchTick

proc replayKeyframeIndex(keyframes: seq[ReplayKeyframe], tick: int): int =
  ## Returns the newest keyframe at or before one tick.
  for i, keyframe in keyframes:
    if keyframe.tick > tick:
      break
    result = i

proc buildReplayKeyframes*(
  data: ReplayData,
  seed: int,
  interval = ReplayKeyframeTicks
): seq[ReplayKeyframe] =
  ## Builds seek keyframes by replaying the whole recording once.
  var
    sim = initSimServer(seed)
    builder = initReplayPlayer(data)
  builder.looping = false
  result.add(builder.saveReplayKeyframe(sim))
  let maxTick = builder.replayMaxTick()
  while builder.playing and sim.tickCount < maxTick:
    builder.stepReplay(sim)
    if sim.tickCount mod max(interval, 1) == 0 or sim.tickCount == maxTick:
      result.add(builder.saveReplayKeyframe(sim))

proc seekReplay*(
  replay: var ReplayPlayer,
  sim: var SimServer,
  keyframes: seq[ReplayKeyframe],
  tick: int
) =
  ## Seeks replay playback to a target tick.
  if keyframes.len == 0:
    return
  replay.restoreReplayKeyframe(
    sim,
    keyframes[keyframes.replayKeyframeIndex(tick)]
  )
  while sim.tickCount < tick and replay.hashIndex < replay.data.hashes.len:
    replay.stepReplay(sim)

proc applyReplaySeek*(
  replay: var ReplayPlayer,
  sim: var SimServer,
  keyframes: seq[ReplayKeyframe],
  tick: int
) =
  ## Seeks replay playback and pauses on the target tick.
  replay.playing = false
  replay.seekReplay(sim, keyframes, clamp(tick, 0, replay.replayMaxTick()))

proc applyReplayCommand*(
  replay: var ReplayPlayer,
  sim: var SimServer,
  keyframes: seq[ReplayKeyframe],
  command: char
) =
  ## Applies one global viewer replay command.
  case command
  of ' ':
    replay.playing = not replay.playing
  of 'p':
    replay.playing = true
  of 'P':
    replay.playing = false
  of '+', '=':
    replay.speedIndex = min(replay.speedIndex + 1, PlaybackSpeeds.high)
  of '-', '_':
    replay.speedIndex = max(replay.speedIndex - 1, 0)
  of '1':
    replay.speedIndex = 0
  of '2':
    replay.speedIndex = 1
  of '3':
    replay.speedIndex = 2
  of '4':
    replay.speedIndex = 3
  of '8':
    replay.speedIndex = 4
  of '6':
    replay.speedIndex = 5
  of ',', '<':
    replay.playing = false
    replay.seekReplay(sim, keyframes, 0)
  of 'b':
    replay.playing = false
    replay.seekReplay(sim, keyframes, max(0, sim.tickCount - 1))
  of 'B':
    replay.playing = false
    replay.seekReplay(
      sim,
      keyframes,
      max(0, sim.tickCount - ReplayFps * 5)
    )
  of 'e':
    replay.playing = false
    replay.seekReplay(sim, keyframes, replay.replayMaxTick())
  of 'r':
    replay.looping = not replay.looping
  of '.', '>':
    replay.playing = false
    replay.seekReplay(
      sim,
      keyframes,
      min(replay.replayMaxTick(), sim.tickCount + ReplayFps * 5)
    )
  else:
    discard

var appState: WebSocketAppState

proc initAppState() =
  initLock(appState.lock)
  appState.inputMasks = initTable[WebSocket, uint8]()
  appState.lastAppliedMasks = initTable[WebSocket, uint8]()
  appState.playerIndices = initTable[WebSocket, int]()
  appState.playerNames = initTable[WebSocket, string]()
  appState.playerSlots = initTable[WebSocket, int]()
  appState.tokens = @[]
  appState.chatMessages = initTable[WebSocket, string]()
  appState.closedSockets = @[]
  appState.spritePlayerViewers = initTable[WebSocket, GlobalViewerState]()
  appState.globalViewers = initTable[WebSocket, GlobalViewerState]()
  appState.rewardViewers = initTable[WebSocket, bool]()
  appState.playerSendReady = initTable[WebSocket, bool]()
  appState.globalSendReady = initTable[WebSocket, bool]()
  appState.rewardSendReady = initTable[WebSocket, bool]()
  appState.socketKinds = initTable[WebSocket, SocketKind]()
  appState.resetRequested = false
  appState.replayServerMode = false
  appState.replayLoaded = false
  appState.pendingReplayUri = ""

proc socketKind(websocket: WebSocket): SocketKind =
  ## Returns the current role for a websocket.
  appState.socketKinds.getOrDefault(websocket, SocketUnknown)

proc removeGlobalSocket(websocket: WebSocket) =
  ## Removes a global viewer websocket.
  if websocket in appState.globalViewers:
    appState.globalViewers.del(websocket)
  if websocket in appState.globalSendReady:
    appState.globalSendReady.del(websocket)
  if websocket in appState.chatMessages:
    appState.chatMessages.del(websocket)
  if websocket in appState.socketKinds:
    appState.socketKinds.del(websocket)

proc removeRewardSocket(websocket: WebSocket) =
  ## Removes a reward viewer websocket.
  if websocket in appState.rewardViewers:
    appState.rewardViewers.del(websocket)
  if websocket in appState.rewardSendReady:
    appState.rewardSendReady.del(websocket)
  if websocket in appState.chatMessages:
    appState.chatMessages.del(websocket)
  if websocket in appState.socketKinds:
    appState.socketKinds.del(websocket)

proc removePlayerSocket(sim: var SimServer, websocket: WebSocket) =
  ## Removes a player websocket and its player slot.
  if websocket in appState.spritePlayerViewers:
    appState.spritePlayerViewers.del(websocket)
  if websocket in appState.playerSendReady:
    appState.playerSendReady.del(websocket)
  if websocket in appState.chatMessages:
    appState.chatMessages.del(websocket)
  if websocket notin appState.playerIndices:
    if websocket in appState.socketKinds:
      appState.socketKinds.del(websocket)
    return

  let removedIndex = appState.playerIndices[websocket]
  appState.playerIndices.del(websocket)
  appState.playerNames.del(websocket)
  appState.playerSlots.del(websocket)
  appState.inputMasks.del(websocket)
  appState.lastAppliedMasks.del(websocket)
  if websocket in appState.socketKinds:
    appState.socketKinds.del(websocket)

  if removedIndex >= 0 and removedIndex < sim.players.len:
    sim.players.delete(removedIndex)
    for ws, value in appState.playerIndices.mpairs:
      if value > removedIndex:
        dec value

proc removeUnknownSocket(sim: var SimServer, websocket: WebSocket) =
  ## Removes a websocket whose role was not recorded.
  if websocket in appState.playerIndices:
    sim.removePlayerSocket(websocket)
    return
  if websocket in appState.globalViewers:
    appState.globalViewers.del(websocket)
  if websocket in appState.rewardViewers:
    appState.rewardViewers.del(websocket)
  if websocket in appState.spritePlayerViewers:
    appState.spritePlayerViewers.del(websocket)
  if websocket in appState.globalSendReady:
    appState.globalSendReady.del(websocket)
  if websocket in appState.rewardSendReady:
    appState.rewardSendReady.del(websocket)
  if websocket in appState.playerSendReady:
    appState.playerSendReady.del(websocket)
  if websocket in appState.inputMasks:
    appState.inputMasks.del(websocket)
  if websocket in appState.lastAppliedMasks:
    appState.lastAppliedMasks.del(websocket)
  if websocket in appState.playerNames:
    appState.playerNames.del(websocket)
  if websocket in appState.chatMessages:
    appState.chatMessages.del(websocket)
  if websocket in appState.socketKinds:
    appState.socketKinds.del(websocket)

proc removeSocket(sim: var SimServer, websocket: WebSocket) =
  ## Removes a websocket according to its recorded role.
  case websocket.socketKind()
  of SocketPlayer:
    sim.removePlayerSocket(websocket)
  of SocketGlobal:
    websocket.removeGlobalSocket()
  of SocketReward:
    websocket.removeRewardSocket()
  of SocketUnknown:
    sim.removeUnknownSocket(websocket)

proc sendGlobalMapPackets(
  sim: var SimServer,
  globalViewers: openArray[WebSocket],
  globalStates: openArray[GlobalViewerState]
) =
  ## Sends one global map or selected player POV frame to all viewers.
  if globalViewers.len == 0:
    return
  for i in 0 ..< globalViewers.len:
    let state =
      if i < globalStates.len:
        globalStates[i]
      else:
        newGlobalViewerState()
    var nextState: GlobalViewerState
    let packetBlob = blobFromBytes(
      buildGlobalViewerPacket(
        sim,
        state,
        nextState
      )
    )
    try:
      globalViewers[i].send(packetBlob, BinaryMessage)
      globalViewers[i].send(SendPingPayload, Ping)
      {.gcsafe.}:
        withLock appState.lock:
          if globalViewers[i].socketKind() == SocketGlobal and
              globalViewers[i] in appState.globalViewers:
            appState.globalViewers[globalViewers[i]] = nextState
            appState.globalSendReady[globalViewers[i]] = false
    except:
      {.gcsafe.}:
        withLock appState.lock:
          sim.removeSocket(globalViewers[i])

proc sendRewardPackets(
  rewardViewers: openArray[WebSocket],
  rewardPacket: string
) =
  ## Sends reward updates to sockets that acknowledged the last frame.
  for websocket in rewardViewers:
    try:
      websocket.send(rewardPacket, TextMessage)
      websocket.send(SendPingPayload, Ping)
      {.gcsafe.}:
        withLock appState.lock:
          if websocket.socketKind() == SocketReward and
              websocket in appState.rewardViewers:
            appState.rewardSendReady[websocket] = false
    except:
      {.gcsafe.}:
        withLock appState.lock:
          websocket.removeRewardSocket()

proc cleanPlayerName(name: string): string =
  result = name.strip()
  for ch in result.mitems:
    if ch.isSpaceAscii:
      ch = '_'

proc playerIdentity(request: Request): string =
  let name = request.queryParams.getOrDefault("name", "").cleanPlayerName()
  if name.len > 0:
    return name
  let parts = request.remoteAddress.splitWhitespace()
  if parts.len >= 2:
    return parts[0] & ":" & parts[1]
  request.remoteAddress

proc playerSlot(request: Request): int =
  ## Returns the requested player slot, or -1 when omitted.
  let text = request.queryParams.getOrDefault("slot", "").strip()
  if text.len == 0:
    return -1
  try:
    result = parseInt(text)
  except ValueError:
    return high(int)
  if result < 0:
    return high(int)

proc playerToken(request: Request): string =
  ## Returns the requested player token.
  request.queryParams.getOrDefault("token", "").strip()

proc playerJoinAllowed(slot: int, token: string): bool =
  ## Returns true when a player request has valid credentials.
  if appState.tokens.len == 0:
    return true
  if slot < 0 or slot >= appState.tokens.len:
    return false
  token == appState.tokens[slot]

proc hasPlayerCredentialParams(name, slot, token: string): bool =
  ## Returns true when query fields identify a player connection.
  name.strip().len > 0 or slot.strip().len > 0 or token.strip().len > 0

proc hasPlayerCredentialParams(request: Request): bool =
  ## Returns true when a websocket request carries player credentials.
  hasPlayerCredentialParams(
    request.queryParams.getOrDefault("name", ""),
    request.queryParams.getOrDefault("slot", ""),
    request.queryParams.getOrDefault("token", "")
  )

proc respondForbidden(request: Request, body: string) =
  ## Rejects a websocket request before upgrade.
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain; charset=utf-8"
  headers["Cache-Control"] = "no-cache"
  headers["Connection"] = "close"
  request.respond(403, headers, body)

proc respondForbiddenViewer(request: Request) =
  ## Rejects a viewer websocket request with player credentials.
  request.respondForbidden(
    "viewer websocket cannot include player name, slot, or token\n"
  )

proc isWebSocketUpgrade(request: Request): bool =
  ## Returns true when the request is a websocket upgrade.
  request.headers["Sec-WebSocket-Key"].len > 0

proc playerChatFromMessage(message: Message): string =
  ## Reads player chat from text or binary websocket messages.
  case message.kind
  of TextMessage:
    message.data
  of BinaryMessage:
    if message.data.isChatPacket():
      return message.data.blobToChat()
    message.data.readSpriteInputText()
  of Ping, Pong:
    ""

proc globalScorePanelClick(
  message: Message
): tuple[found: bool, x: int, y: int] =
  ## Returns one score panel mouse-down click from a global viewer message.
  if message.kind != BinaryMessage:
    return
  var
    x = 0
    y = 0
    layer = GlobalLayerId
  for item in message.data.parseSpriteClientMessages():
    case item.kind
    of SpriteClientMouseMoveMessage:
      x = item.x
      y = item.y
      layer =
        if item.hasLayer:
          item.layer
        else:
          GlobalLayerId
    of SpriteClientMouseButtonMessage:
      if layer == GlobalScorePanelLayerId and item.button == 1'u8 and
          item.down:
        return (found: true, x: x, y: y)
    of SpriteClientChatMessage, SpriteClientInputMessage:
      discard

proc serveHealthz(request: Request): bool =
  ## Serves the container health check endpoint.
  if request.path != HealthPath or request.httpMethod notin ["GET", "HEAD"]:
    return false
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain; charset=utf-8"
  headers["Cache-Control"] = "no-cache"
  request.respond(200, headers, "healthy")
  true

proc respondPlain(request: Request, code: int, body: string) =
  ## Sends one plain text response.
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain; charset=utf-8"
  request.respond(code, headers, body)

proc replayFilePath(uri: string): string =
  ## Resolves one local replay URI to a host path.
  const FilePrefix = "file://"
  if uri.startsWith(FilePrefix):
    return uri[FilePrefix.len .. ^1]
  if "://" in uri:
    return ""
  uri

let replayDownloadPool = newCurlPool(1)

proc loadReplayUri(uri: string): ReplayData =
  ## Loads a replay from a local file URI or HTTP(S) URL.
  parseReplayBytes(readCogameUri(uri, CogameLoadReplayUriEnv))

proc readableReplayUri(uri: string): bool =
  ## Returns true when a replay URI can be opened by this server.
  if uri.len == 0:
    return false
  if uri.startsWith("http://") or uri.startsWith("https://"):
    return replayDownloadPool.head(uri).code == 200
  let path = replayFilePath(uri)
  path.len > 0 and fileExists(path)

proc replayRequestUri(request: Request): string =
  ## Returns the replay artifact URI requested by a Coworld replay client.
  request.queryParams.getOrDefault("uri", "").strip()

proc checkReplayRequest(request: Request): bool =
  ## Validates one replay page or websocket request, capturing the
  ## requested replay URI for the playback loop. Returns false after
  ## responding with an error.
  result = true
  var
    replayServerMode = false
    replayLoaded = false
  {.gcsafe.}:
    withLock appState.lock:
      replayServerMode = appState.replayServerMode
      replayLoaded = appState.replayLoaded
  if not replayServerMode:
    return true
  let uri = request.replayRequestUri()
  if uri.len == 0:
    if replayLoaded:
      return true
    request.respondPlain(400, "missing replay uri\n")
    return false
  var readable = false
  {.gcsafe.}:
    readable = uri.readableReplayUri()
  if not readable:
    request.respondPlain(404, "replay uri is not readable\n")
    return false
  {.gcsafe.}:
    withLock appState.lock:
      appState.pendingReplayUri = uri
  return true

proc httpHandler(request: Request) =
  if request.serveHealthz():
    discard
  elif request.path == ReplayWebSocketPath and request.httpMethod == "GET" and
      not request.isWebSocketUpgrade():
    if not request.checkReplayRequest():
      return
    discard serveClientFile(
      request,
      ReplayClientRoute,
      GlobalClientRoute
    )
  elif request.path in [ReplayClientRoute, CoworldReplayClientRoute] and
      request.httpMethod == "GET":
    if not request.checkReplayRequest():
      return
    discard serveClientFile(
      request,
      request.path,
      GlobalClientRoute
    )
  elif request.path == PlayerWebSocketPath and
      request.httpMethod == "GET" and
      request.isWebSocketUpgrade():
    let
      slot = request.playerSlot()
      token = request.playerToken()
    var allowed = false
    {.gcsafe.}:
      withLock appState.lock:
        allowed = playerJoinAllowed(slot, token)
    if not allowed:
      request.respondForbidden("player token rejected\n")
      return
    let websocket = request.upgradeToWebSocket()
    {.gcsafe.}:
      withLock appState.lock:
        if websocket in appState.globalViewers:
          appState.globalViewers.del(websocket)
        if websocket in appState.globalSendReady:
          appState.globalSendReady.del(websocket)
        if websocket in appState.rewardViewers:
          appState.rewardViewers.del(websocket)
        if websocket in appState.rewardSendReady:
          appState.rewardSendReady.del(websocket)
        if websocket in appState.chatMessages:
          appState.chatMessages.del(websocket)
        appState.socketKinds[websocket] = SocketPlayer
        appState.playerNames[websocket] = request.playerIdentity()
        appState.playerSlots[websocket] = slot
        appState.spritePlayerViewers[websocket] = newGlobalViewerState()
        appState.playerSendReady[websocket] = true
        appState.playerIndices[websocket] = 0x7fffffff
        appState.inputMasks[websocket] = 0
        appState.lastAppliedMasks[websocket] = 0
  elif (request.path == GlobalWebSocketPath or
      request.path == ReplayWebSocketPath or
      request.path == AdminWebSocketPath) and
      request.httpMethod == "GET" and request.isWebSocketUpgrade():
    if request.hasPlayerCredentialParams():
      request.respondForbiddenViewer()
      return
    if request.path == ReplayWebSocketPath and
        not request.checkReplayRequest():
      return
    let websocket = request.upgradeToWebSocket()
    {.gcsafe.}:
      withLock appState.lock:
        if websocket in appState.rewardViewers:
          appState.rewardViewers.del(websocket)
        if websocket in appState.rewardSendReady:
          appState.rewardSendReady.del(websocket)
        if websocket in appState.spritePlayerViewers:
          appState.spritePlayerViewers.del(websocket)
        if websocket in appState.playerSendReady:
          appState.playerSendReady.del(websocket)
        if websocket in appState.inputMasks:
          appState.inputMasks.del(websocket)
        if websocket in appState.lastAppliedMasks:
          appState.lastAppliedMasks.del(websocket)
        if websocket in appState.playerIndices:
          appState.playerIndices.del(websocket)
        if websocket in appState.playerNames:
          appState.playerNames.del(websocket)
        if websocket in appState.chatMessages:
          appState.chatMessages.del(websocket)
        appState.socketKinds[websocket] = SocketGlobal
        appState.globalViewers[websocket] = newGlobalViewerState()
        appState.globalSendReady[websocket] = true
  elif request.path == RewardWebSocketPath and request.httpMethod == "GET" and
      request.isWebSocketUpgrade():
    if request.hasPlayerCredentialParams():
      request.respondForbiddenViewer()
      return
    let websocket = request.upgradeToWebSocket()
    {.gcsafe.}:
      withLock appState.lock:
        if websocket in appState.globalViewers:
          appState.globalViewers.del(websocket)
        if websocket in appState.globalSendReady:
          appState.globalSendReady.del(websocket)
        if websocket in appState.spritePlayerViewers:
          appState.spritePlayerViewers.del(websocket)
        if websocket in appState.playerSendReady:
          appState.playerSendReady.del(websocket)
        if websocket in appState.inputMasks:
          appState.inputMasks.del(websocket)
        if websocket in appState.lastAppliedMasks:
          appState.lastAppliedMasks.del(websocket)
        if websocket in appState.playerIndices:
          appState.playerIndices.del(websocket)
        if websocket in appState.playerNames:
          appState.playerNames.del(websocket)
        if websocket in appState.chatMessages:
          appState.chatMessages.del(websocket)
        appState.socketKinds[websocket] = SocketReward
        appState.rewardViewers[websocket] = true
        appState.rewardSendReady[websocket] = true
  elif request.serveClientRoute(GlobalClientRoute):
    discard
  else:
    var headers: HttpHeaders
    headers["Content-Type"] = "text/plain"
    request.respond(200, headers, "BitWorld WebSocket server")

proc websocketHandler(
  websocket: WebSocket,
  event: WebSocketEvent,
  message: Message
) =
  case event
  of OpenEvent:
    discard
  of MessageEvent:
    if message.kind == Ping:
      websocket.send(message.data, Pong)
      return
    if message.kind == Pong:
      {.gcsafe.}:
        withLock appState.lock:
          case websocket.socketKind()
          of SocketPlayer:
            if websocket in appState.playerSendReady:
              appState.playerSendReady[websocket] = true
          of SocketGlobal:
            if websocket in appState.globalSendReady:
              appState.globalSendReady[websocket] = true
          of SocketReward:
            if websocket in appState.rewardSendReady:
              appState.rewardSendReady[websocket] = true
          of SocketUnknown:
            discard
      return
    let scorePanelClick = message.globalScorePanelClick()
    if scorePanelClick.found:
      {.gcsafe.}:
        withLock appState.lock:
          if websocket.socketKind() == SocketGlobal and
              websocket in appState.globalViewers:
            let state = appState.globalViewers[websocket]
            state.pendingScorePanelClick = true
            state.pendingScorePanelClickX = scorePanelClick.x
            state.pendingScorePanelClickY = scorePanelClick.y
            appState.globalSendReady[websocket] = true
    if message.kind == BinaryMessage:
      {.gcsafe.}:
        withLock appState.lock:
          if appState.replayServerMode and
              websocket.socketKind() == SocketGlobal and
              websocket in appState.globalViewers:
            appState.globalViewers[websocket].applyReplayViewerMouse(
              message.data
            )
    let chatText = message.playerChatFromMessage().cleanChatMessage()
    if message.kind == BinaryMessage and
        isSpritePlayerInputPacket(message.data):
      {.gcsafe.}:
        withLock appState.lock:
          if websocket.socketKind() == SocketPlayer and
              websocket in appState.inputMasks:
            appState.inputMasks[websocket] = message.data[1].uint8 and 0x7f'u8
    if chatText.len > 0:
      {.gcsafe.}:
        withLock appState.lock:
          if websocket.socketKind() == SocketPlayer and
              websocket in appState.playerIndices:
            appState.chatMessages[websocket] = chatText
  of ErrorEvent:
    discard
  of CloseEvent:
    {.gcsafe.}:
      withLock appState.lock:
        appState.closedSockets.add(websocket)

proc serverThreadProc(args: ServerThreadArgs) {.thread.} =
  args.server[].serve(Port(args.port), args.address)

proc runFrameLimiter(previousTick: var MonoTime) =
  let
    frameDuration = initDuration(nanoseconds = 1_000_000_000 div TargetFps)
    targetTick = previousTick + frameDuration
  if getMonoTime() < targetTick:
    let sleepMs = (targetTick - getMonoTime()).inMilliseconds
    if sleepMs > 1:
      sleep(int(sleepMs - 1))
    while getMonoTime() < targetTick:
      discard
    previousTick = targetTick
  else:
    previousTick = getMonoTime()

proc tickLimitText(value: int): string =
  ## Returns a readable tick limit description.
  if value == 0:
    "infinite"
  else:
    $value

proc finalizeReplayRecording(
  replayWriter: var ReplayWriter,
  saveReplayPath: string,
  runtimeConfig: RuntimeConfig
) =
  ## Closes the first-game recording and uploads the replay artifact.
  if not replayWriter.enabled:
    return
  replayWriter.closeReplayWriter()
  if fileExists(saveReplayPath):
    echo "Replay written: ", saveReplayPath,
      " (", getFileSize(saveReplayPath), " bytes)"
    runtimeConfig.writeReplay(readFile(saveReplayPath))

proc runServerLoop(
  host = DefaultHost,
  port = DefaultPort,
  seed = 0x1F1B10C,
  maxTicks = DefaultMaxTicks,
  maxGames = 0,
  runtimeConfig = RuntimeConfig(),
  tokens: seq[string] = @[],
  saveReplayPath = ""
) =
  initAppState()
  appState.tokens = tokens
  var replayWriter = openReplayWriter(
    saveReplayPath,
    $(%*{
      "seed": seed,
      "maxTicks": maxTicks,
      "maxGames": maxGames,
      "tokenCount": tokens.len
    })
  )

  let httpServer = newServer(
    httpHandler,
    websocketHandler,
    workerThreads = 4,
    tcpNoDelay = true
  )

  var serverThread: Thread[ServerThreadArgs]
  var serverPtr = cast[ptr Server](unsafeAddr httpServer)
  createThread(serverThread, serverThreadProc, ServerThreadArgs(server: serverPtr, address: host, port: port))
  httpServer.waitUntilReady()

  var
    currentSeed = seed
    sim = initSimServer(currentSeed)
    lastTick = getMonoTime()
    runTicks = 0
    gamesFinished = 0
    lastScores = ""
  echo "Infinite Blocks config: maxTicks=", maxTicks.tickLimitText(),
    " maxGames=", maxGames.tickLimitText(),
    " targetFps=", TargetFps

  while true:
    var
      sockets: seq[WebSocket] = @[]
      playerIndices: seq[int] = @[]
      playerGlobalStates: seq[GlobalViewerState] = @[]
      inputs: seq[InputState]
      shouldReset = false
      globalViewers: seq[WebSocket] = @[]
      globalStates: seq[GlobalViewerState] = @[]
      rewardViewers: seq[WebSocket] = @[]

    {.gcsafe.}:
      withLock appState.lock:
        for websocket in appState.closedSockets:
          if replayWriter.enabled and
              websocket.socketKind() == SocketPlayer and
              websocket in appState.playerIndices:
            let playerIndex = appState.playerIndices[websocket]
            if playerIndex >= 0 and playerIndex < sim.players.len:
              replayWriter.writeLeave(tickTime(sim.tickCount), playerIndex)
              if playerIndex < replayWriter.lastMasks.len:
                replayWriter.lastMasks.delete(playerIndex)
          sim.removeSocket(websocket)
        appState.closedSockets.setLen(0)

        if appState.resetRequested:
          shouldReset = true
          appState.resetRequested = false
          for websocket, value in appState.playerIndices.mpairs:
            if websocket.socketKind() == SocketPlayer:
              value = 0x7fffffff
          for _, value in appState.inputMasks.mpairs:
            value = 0
          for _, value in appState.lastAppliedMasks.mpairs:
            value = 0
          appState.chatMessages.clear()
        else:
          for websocket in appState.playerIndices.keys:
            if websocket.socketKind() != SocketPlayer:
              continue
            if appState.playerIndices[websocket] == 0x7fffffff:
              let
                name = appState.playerNames.getOrDefault(websocket, "unknown")
                playerIndex = sim.addPlayer(name)
              appState.playerIndices[websocket] = playerIndex
              if replayWriter.enabled:
                replayWriter.writeJoin(
                  tickTime(sim.tickCount),
                  playerIndex,
                  name,
                  appState.playerSlots.getOrDefault(websocket, -1),
                  ""
                )
                while replayWriter.lastMasks.len < sim.players.len:
                  replayWriter.lastMasks.add(0)

          inputs = newSeq[InputState](sim.players.len)
          for websocket, playerIndex in appState.playerIndices.pairs:
            if websocket.socketKind() != SocketPlayer:
              continue
            if playerIndex < 0 or playerIndex >= inputs.len:
              continue
            let currentMask = appState.inputMasks.getOrDefault(websocket, 0)
            let previousMask = appState.lastAppliedMasks.getOrDefault(websocket, 0)
            inputs[playerIndex] = decodeInputMask(currentMask)
            inputs[playerIndex].attack =
              (currentMask and ButtonA) != 0 and (previousMask and ButtonA) == 0
            appState.lastAppliedMasks[websocket] = currentMask
            replayWriter.writeInputMaskChange(
              tickTime(sim.tickCount),
              playerIndex,
              currentMask
            )
            let chatText = appState.chatMessages.getOrDefault(websocket, "")
            if chatText.len > 0:
              sim.applyPlayerChat(playerIndex, chatText)
              replayWriter.writeChat(
                tickTime(sim.tickCount),
                playerIndex,
                chatText
              )
              appState.chatMessages.del(websocket)
            if appState.playerSendReady.getOrDefault(websocket, true):
              sockets.add(websocket)
              playerIndices.add(playerIndex)
              if websocket notin appState.spritePlayerViewers:
                appState.spritePlayerViewers[websocket] = newGlobalViewerState()
              playerGlobalStates.add(appState.spritePlayerViewers[websocket])

        for websocket in appState.rewardViewers.keys:
          if websocket.socketKind() == SocketReward and
              appState.rewardSendReady.getOrDefault(websocket, true):
            rewardViewers.add(websocket)
        for websocket, state in appState.globalViewers.pairs:
          if websocket.socketKind() == SocketGlobal and
              appState.globalSendReady.getOrDefault(websocket, true):
            globalViewers.add(websocket)
            globalStates.add(state)

    if shouldReset:
      sim.writeScoresIfChanged(lastScores, runtimeConfig, tokens.len)
      # Only the first game of a run is recorded and uploaded.
      replayWriter.finalizeReplayRecording(saveReplayPath, runtimeConfig)
      inc currentSeed
      sim = initSimServer(currentSeed)
      runTicks = 0
      echo "Infinite Blocks game reset: seed=", currentSeed,
        " gamesFinished=", gamesFinished,
        " maxGames=", maxGames.tickLimitText()
      {.gcsafe.}:
        withLock appState.lock:
          for websocket in appState.playerIndices.keys:
            if websocket.socketKind() != SocketPlayer:
              continue
            if appState.playerIndices[websocket] == 0x7fffffff:
              let name = appState.playerNames.getOrDefault(websocket, "unknown")
              appState.playerIndices[websocket] = sim.addPlayer(name)
            if appState.playerSendReady.getOrDefault(websocket, true):
              sockets.add(websocket)
              playerIndices.add(appState.playerIndices[websocket])
              if websocket notin appState.spritePlayerViewers:
                appState.spritePlayerViewers[websocket] = newGlobalViewerState()
              playerGlobalStates.add(appState.spritePlayerViewers[websocket])
      for i in 0 ..< sockets.len:
        var nextState: GlobalViewerState
        let framePacket = blobFromBytes(
          buildPlayerViewerPacket(
            sim,
            playerIndices[i],
            playerGlobalStates[i],
            nextState
          )
        )
        {.gcsafe.}:
          withLock appState.lock:
            if sockets[i].socketKind() == SocketPlayer and
                sockets[i] in appState.spritePlayerViewers:
              appState.spritePlayerViewers[sockets[i]] = nextState
        sockets[i].send(framePacket, BinaryMessage)
        sockets[i].send(SendPingPayload, Ping)
        {.gcsafe.}:
          withLock appState.lock:
            if sockets[i].socketKind() == SocketPlayer and
                sockets[i] in appState.playerSendReady:
              appState.playerSendReady[sockets[i]] = false
      let rewardPacket = sim.buildRewardPacket()
      sendRewardPackets(rewardViewers, rewardPacket)
      sim.sendGlobalMapPackets(globalViewers, globalStates)
      runFrameLimiter(lastTick)
      continue

    sim.step(inputs)
    replayWriter.writeHash(uint32(sim.tickCount), sim.gameHash())
    inc runTicks

    for i in 0 ..< sockets.len:
      var nextState: GlobalViewerState
      let frameBlob = blobFromBytes(
        buildPlayerViewerPacket(
          sim,
          playerIndices[i],
          playerGlobalStates[i],
          nextState
        )
      )
      {.gcsafe.}:
        withLock appState.lock:
          if sockets[i].socketKind() == SocketPlayer and
              sockets[i] in appState.spritePlayerViewers:
            appState.spritePlayerViewers[sockets[i]] = nextState
      try:
        sockets[i].send(frameBlob, BinaryMessage)
        sockets[i].send(SendPingPayload, Ping)
        {.gcsafe.}:
          withLock appState.lock:
            if sockets[i].socketKind() == SocketPlayer and
                sockets[i] in appState.playerSendReady:
              appState.playerSendReady[sockets[i]] = false
      except:
        {.gcsafe.}:
          withLock appState.lock:
            sim.removeSocket(sockets[i])

    let rewardPacket = sim.buildRewardPacket()
    sendRewardPackets(rewardViewers, rewardPacket)

    if runTicks mod GlobalSendInterval == 0:
      sim.sendGlobalMapPackets(globalViewers, globalStates)

    if maxTicks > 0 and runTicks >= maxTicks:
      inc gamesFinished
      echo "Infinite Blocks maxTicks reached: ticks=", runTicks,
        " gamesFinished=", gamesFinished,
        " maxGames=", maxGames.tickLimitText()
      sim.writeScoresIfChanged(lastScores, runtimeConfig, tokens.len)
      # Only the first game of a run is recorded and uploaded.
      replayWriter.finalizeReplayRecording(saveReplayPath, runtimeConfig)
      if maxGames > 0 and gamesFinished >= maxGames:
        echo "Infinite Blocks maxGames reached, shutting down."
        httpServer.close()
        joinThread(serverThread)
        break
      {.gcsafe.}:
        withLock appState.lock:
          appState.resetRequested = true

    runFrameLimiter(lastTick)

proc readConfigInt(node: JsonNode, name: string, value: var int) =
  if not node.hasKey(name):
    return
  let item = node[name]
  if item.kind != JInt:
    raise newException(ValueError, "Config field " & name & " must be an integer.")
  value = item.getInt()

proc readConfigStrings(node: JsonNode, name: string, values: var seq[string]) =
  ## Reads one optional string array config field.
  if not node.hasKey(name):
    return
  let items = node[name]
  if items.kind != JArray:
    raise newException(
      ValueError,
      "Config field " & name & " must be an array."
    )
  values.setLen(0)
  for i in 0 ..< items.len:
    let item = items[i]
    if item.kind != JString:
      raise newException(
        ValueError,
        "Config field " & name & "[" & $i & "] must be a string."
      )
    values.add(item.getStr())

proc update(config: var RunConfig, jsonText: string) =
  if jsonText.len == 0:
    return
  var node: JsonNode
  try:
    node = fromJson(jsonText)
  except jsony.JsonError as e:
    raise newException(ValueError, "Could not parse config JSON: " & e.msg)
  if node.kind != JObject:
    raise newException(ValueError, "Config must be a JSON object.")
  node.readConfigInt("seed", config.seed)
  node.readConfigInt("maxTicks", config.maxTicks)
  node.readConfigInt("max-ticks", config.maxTicks)
  node.readConfigInt("maxGames", config.maxGames)
  node.readConfigInt("max-games", config.maxGames)
  node.readConfigStrings("tokens", config.tokens)

proc limitText(value: int): string =
  ## Returns a readable text value for a numeric limit.
  if value > 0:
    $value
  else:
    "infinite"

proc echoStartupConfig(config: RunConfig) =
  ## Prints the effective startup config without token secrets.
  echo "Infinite Blocks config: host=", config.address,
    " port=", config.port,
    " seed=", config.seed,
    " tokens=", config.tokens.len,
    " maxTicks=", config.maxTicks.limitText(),
    " maxGames=", config.maxGames.limitText()

proc replayRunConfigFor(data: ReplayData): RunConfig =
  ## Reads the recorded simulation config from a replay header.
  result = RunConfig(
    address: DefaultHost,
    port: DefaultPort,
    seed: 0x1F1B10C,
    maxTicks: DefaultMaxTicks,
    maxGames: 0,
    tokens: @[]
  )
  result.update(data.configJson)

proc runReplayServerLoop(
  host = DefaultHost,
  port = DefaultPort,
  runtimeConfig = RuntimeConfig()
) =
  ## Serves recorded Infinite Blocks replays to replay and global viewers.
  initAppState()
  appState.replayServerMode = true

  var
    replayData = ReplayData()
    replaySeed = 0x1F1B10C
    replayLoaded = false
    keyframes: seq[ReplayKeyframe] = @[]
  if runtimeConfig.replay.len > 0:
    replayData = parseReplayBytes(runtimeConfig.replay)
    replaySeed = replayData.replayRunConfigFor().seed
    keyframes = replayData.buildReplayKeyframes(replaySeed)
    replayLoaded = true
  appState.replayLoaded = replayLoaded

  let httpServer = newServer(
    httpHandler,
    websocketHandler,
    workerThreads = 4,
    tcpNoDelay = true
  )
  var serverThread: Thread[ServerThreadArgs]
  var serverPtr = cast[ptr Server](unsafeAddr httpServer)
  createThread(
    serverThread,
    serverThreadProc,
    ServerThreadArgs(server: serverPtr, address: host, port: port)
  )
  httpServer.waitUntilReady()

  var
    sim = initSimServer(replaySeed)
    replay =
      if replayLoaded:
        initReplayPlayer(replayData)
      else:
        ReplayPlayer()
    lastTick = getMonoTime()
    frameCount = 0

  while true:
    var
      pendingReplayUri = ""
      globalViewers: seq[WebSocket] = @[]
      globalStates: seq[GlobalViewerState] = @[]

    {.gcsafe.}:
      withLock appState.lock:
        pendingReplayUri = appState.pendingReplayUri
        appState.pendingReplayUri = ""
        for websocket in appState.closedSockets:
          sim.removeSocket(websocket)
        appState.closedSockets.setLen(0)

    if pendingReplayUri.len > 0:
      try:
        replayData = loadReplayUri(pendingReplayUri)
        replaySeed = replayData.replayRunConfigFor().seed
        sim = initSimServer(replaySeed)
        replay = initReplayPlayer(replayData)
        keyframes = replayData.buildReplayKeyframes(replaySeed)
        replayLoaded = true
        {.gcsafe.}:
          withLock appState.lock:
            appState.replayLoaded = true
      except CatchableError as e:
        echo "Could not load replay uri: ", e.msg

    var
      replayCommands: seq[char] = @[]
      replaySeekTick = -1
    let maxTick = replay.replayMaxTick()
    {.gcsafe.}:
      withLock appState.lock:
        for websocket, state in appState.globalViewers.pairs:
          if websocket.socketKind() != SocketGlobal:
            continue
          if state.mousePressed:
            state.mousePressed = false
            if state.mouseLayer == GlobalReplayControlsLayerId:
              let command = replayControlCommandAt(
                state.mouseX,
                state.mouseY
              )
              if command != '\0':
                replayCommands.add(command)
              let scrubTick = replayScrubTickAt(
                state.mouseX,
                state.mouseY,
                maxTick
              )
              if scrubTick >= 0:
                state.scrubbingReplay = true
                replaySeekTick = scrubTick
          if state.scrubbingReplay and state.mouseDown and
              state.mouseLayer == GlobalReplayControlsLayerId:
            let scrubTick = replayScrubTickAt(
              state.mouseX,
              state.mouseY,
              maxTick,
              requireInside = false
            )
            if scrubTick >= 0:
              replaySeekTick = scrubTick
          if state.mouseReleased:
            state.mouseReleased = false
            state.scrubbingReplay = false
          if appState.globalSendReady.getOrDefault(websocket, true):
            globalViewers.add(websocket)
            globalStates.add(state)

    if replayLoaded:
      if replaySeekTick >= 0:
        if replaySeekTick != sim.tickCount:
          echo "Replay seek to tick ", replaySeekTick
          replay.applyReplaySeek(sim, keyframes, replaySeekTick)
        else:
          replay.playing = false
      for command in replayCommands:
        echo "Replay command: ", command.repr
        replay.applyReplayCommand(sim, keyframes, command)
      if replay.playing:
        for _ in 0 ..< replay.replaySpeed():
          if replay.playing:
            replay.stepReplay(sim)
        if replay.looping and not replay.playing and maxTick > 0:
          replay.seekReplay(sim, keyframes, 0)
          replay.playing = true

    if frameCount mod GlobalSendInterval == 0 and globalViewers.len > 0:
      let
        barKey = replayBarKey(
          sim.tickCount,
          maxTick,
          replay.playing,
          replay.looping,
          replay.speedIndex
        )
        bar = sim.buildReplayControlsSprite(
          sim.tickCount,
          maxTick,
          replay.playing,
          replay.looping,
          replay.speedIndex
        )
      for i in 0 ..< globalViewers.len:
        var nextState: GlobalViewerState
        var packet = buildGlobalViewerPacket(
          sim,
          globalStates[i],
          nextState
        )
        packet.addReplayControls(nextState, bar, barKey)
        let packetBlob = blobFromBytes(packet)
        try:
          globalViewers[i].send(packetBlob, BinaryMessage)
          globalViewers[i].send(SendPingPayload, Ping)
          {.gcsafe.}:
            withLock appState.lock:
              if globalViewers[i].socketKind() == SocketGlobal and
                  globalViewers[i] in appState.globalViewers:
                appState.globalViewers[globalViewers[i]] = nextState
                appState.globalSendReady[globalViewers[i]] = false
        except CatchableError:
          {.gcsafe.}:
            withLock appState.lock:
              sim.removeSocket(globalViewers[i])
    inc frameCount

    runFrameLimiter(lastTick)

when isMainModule:
  let runtimeConfig = readRuntimeConfig()
  var
    config = RunConfig(
      address: runtimeConfig.host,
      port: runtimeConfig.port,
      seed: 0x1F1B10C,
      maxTicks: DefaultMaxTicks,
      maxGames: 0,
      tokens: @[]
    )
  config.update(runtimeConfig.config)
  config.echoStartupConfig()
  if runtimeConfig.resultsUri.len > 0:
    echo "Using results target: " & runtimeConfig.resultsUri
  if runtimeConfig.replayUri.len > 0:
    echo "Using replay target: " & runtimeConfig.replayUri
  if runtimeConfig.replayMode:
    runReplayServerLoop(config.address, config.port, runtimeConfig)
    quit(0)
  let localReplayPath =
    if runtimeConfig.replayUri.len > 0:
      getTempDir() / ("infinite-blocks-replay-" & $getCurrentProcessId() &
        ".bitreplay")
    else:
      ""
  runServerLoop(
    config.address,
    config.port,
    seed = config.seed,
    maxTicks = config.maxTicks,
    maxGames = config.maxGames,
    runtimeConfig = runtimeConfig,
    tokens = config.tokens,
    saveReplayPath = localReplayPath
  )
