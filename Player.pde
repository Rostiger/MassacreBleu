class Player extends GameObject {

	//properties
	PVector startPos, dir, speed, sizCore, shieldHp;

	int id, alpha;
	float minCharge, maxCharge, drawScale, initialDrawScale, drawScaleShield;
	boolean ALIVE, KILLED, INVINCIBLE;
	boolean hit, knockBack, hasMultiShot, hasShield, hasLockDown;
	boolean wrapH, wrapV;
	
	// stats
	int bullets, kills, deaths, shots, items, score, nodesOwned, nodesCaptured, nodesLost, wins;
	boolean spawnedOnce;

	//counters
	float initialRespawnDuration, respawnDuration, respawnTime, respawnDurationMultiplier;
	float invincibleDuration, invincibleTime;
	float shootDelayDuration, shootDelayTime;
	int trailCount;
	float charge, chargeDelay, initChargeDelay;

	//cursor
	PVector cursorPos, cursorSiz;

	// boosting
	boolean hasBoost, boosting;
	int boostDuration = 30;
	int boostTime = boostDuration;
	ArrayList <TrailParticle> boostParticles = new ArrayList <TrailParticle>();

	//multishot
	float msIndicatorSize, msMaxSize;

	// item display
	int itemAlpha;
	boolean showItem;
	float itemYPos, itemShowDuration;
	String currentItem, prevItem = "";

	Input input;
	
	Player(int _id, PVector _startPos) {

		id = _id;
		input = new Input(id);

		// set player variables
		startPos 	= new PVector( _startPos.x, _startPos.y );
		pos 		= new PVector( startPos.x, startPos.y );
		cen 		= new PVector( pos.x + siz.x / 2, pos.y + siz.x / 2);
		sizCore		= new PVector( siz.x, siz.y );
		cursorPos 	= new PVector( pos.x, pos.y );
		cursorSiz 	= new PVector( siz.x, siz.y );
		speed 		= new PVector( 0,0 );
		dir 		= new PVector( 0,1 );
		hp 			= new PVector( 10,10 );
		shieldHp 	= new PVector( 10,10 );

		wins = 0;
		
		if (input.hasGamePad) println("Player " + id + " uses a game pad.");
		else  println("Player " + id + " doesn't use a game pad.");
	}

	void reset() {
		// reset is called at every start of the level and is used to (re)initialise player variables
		siz = new PVector( CELL_SIZE, CELL_SIZE );

		hit = false;
		ALIVE = false;
		INVINCIBLE = false;
		KILLED = false;
		boosting = false;
		hasBoost = false;
		hasMultiShot = false;
		hasShield = false;
		hasLockDown = false;
		showItem = false;
		spawnedOnce = false;
		
		//properties
		alpha = 255;
		initialDrawScale = 5;
		drawScale = initialDrawScale;
		drawScaleShield = 1;
		wrapH = false;
		wrapV = false;

		//stats
		bullets = 0;
		score = 0;
		deaths = 0;
		kills = 0;
		items = 0;
		nodesOwned = 0;
		nodesCaptured = 0;
		nodesLost = 0;
		if (gManager.gameOver) wins = 0;
		pos.set(startPos);

		// bullet charge
		maxCharge = CELL_SIZE;
		minCharge = CELL_SIZE / 2;
		charge = minCharge;
		initChargeDelay = 0.01;
		chargeDelay = initChargeDelay;
		shootDelayDuration = 1.5;
		shootDelayTime = 0;

		// respawn timers
		respawnDuration = 0;
		respawnTime = respawnDuration;
		respawnDurationMultiplier = 2;
		// invicibility
		invincibleDuration = 2;
		invincibleTime = invincibleDuration;
		// boost
		trailCount = 100000;

		// multishot
		msMaxSize = siz.x / 6;
		msIndicatorSize = msMaxSize;
		// shield
		shieldHp.x = 0;
	}

	void update() {
		// update the inputs if the debug console isn't open
		if (!gManager.debug) input.update();

		// pauses the game
		if (input.startReleased) {
			if (gManager.matchOver) {
				if (hud.showEndScreen) gManager.reset();
			} else {
				gManager.paused = !gManager.paused;
				menu.setUser(id);
			}
		}

		updateVectors();

		if (!KILLED) move();
		draw();
		face();
		boost();
		
		if (ALIVE && !KILLED) {

			if (drawScale > 1) drawScale *= 0.8;
			else drawScale = 1;

			if (drawScaleShield > 1) drawScaleShield *= 0.8;
			else drawScaleShield = 1;

			//if the player is invincible, count down the timer and start blinking
			if (INVINCIBLE) {
				if (invincibleTime > 0) {
					alpha = blink.blink(0,255,3);
					invincibleTime -= 1 * dtInSeconds;

				} else {
					if (!debugger.invincibility) INVINCIBLE = false;
					invincibleTime = invincibleDuration;
					alpha = 255;
				
				}

			} else hit();

			// if hp.x goes under 0, kill the player
			if (hp.x <= 0) die();

			// maintain the shield status
			if (shieldHp.x <= 0) hasShield = false;
			else hasShield = true;
			
			if(!gManager.matchOver) {

				if (shootDelayTime > 0) shootDelayTime--;
				else shoot();

				useItem();
				checkNodeCount();
			}

		} else if (KILLED) {
			// reset any powerups
			boosting = false;
			hasBoost = false;
			hasMultiShot = false;
			hasShield = false;
			hasLockDown = false;
			showItem = false;		
			
			// decrease alpha && increase drawScale
			if (alpha > 0) {
				alpha -= 10;
				drawScale++;
			} else if (!gManager.matchOver) {
				ALIVE = false;
				KILLED = false;
			}

		} else {
			// count down until respawn is possible
			if (respawnTime > 0) respawnTime -= 1 * dtInSeconds;
			else if (input.shootReleased && !gManager.matchOver) spawn();
		}
	}

	void useItem() {
		if (input.useItemPressed && ALIVE && !KILLED) {

			if (hasLockDown) {
				for (Node n : oManager.nodes) {
					n.wasLockedDown = true;
				}
				hasLockDown = false;
			}
			
			if (hasBoost && !boosting) {
				boosting = true;
				hasBoost = false;
				boost01.trigger();
			}

			if (hasMultiShot) {
				multiShot01.trigger();

				for (int xD = -1; xD <= 1; xD++) {
					for (int yD = -1; yD <= 1; yD++) {

					    if (xD != 0 || yD != 0) {
					    	PVector direction = new PVector( xD, yD );
					    	oManager.addBullet(id,cen,direction,maxCharge * 0.7);
					    }

					}
				}
				hasMultiShot = false;
			}
		}
	}

	void checkNodeCount() {
		//check how many nodes the player owns (must be more than one)
		if (nodesOwned == oManager.nodes.size() && nodesOwned != 0 && !gManager.matchOver) {
			wins ++;
			if (wins == 3) gManager.gameOver = true;
			gManager.matchOver = true;
			gManager.winnerID = id;
		}		
	}

	void updateVectors() {
		cen.x = pos.x + siz.x / 2;
		cen.y = pos.y + siz.y / 2;

		sizCore.x = siz.x / 2 * hp.x / 10;
		sizCore.y = siz.y / 2 * hp.x / 10;

		cursorSiz.x = charge / 4;
		cursorSiz.y = charge / 4;
	}

	void draw() {

		canvas.rectMode(CENTER);

		if (ALIVE) {
			// player background
			canvas.strokeWeight(siz.x / 32);	
			canvas.fill(colors.player[id],alpha/5);
			canvas.stroke(colors.player[id],alpha);
			canvas.rect(cen.x,cen.y,siz.x * drawScale,siz.y * drawScale);

			//draw the player core background
			canvas.noStroke();
			canvas.fill(colors.player[id],alpha/3);
			canvas.rect(cen.x,cen.y,siz.x/2 * drawScale,siz.y/2 * drawScale);

			// draw the multishot indicator
			if (hasMultiShot) drawMultiShotIndicator();

			// draw the boost indicator
			if (hasBoost) drawBoostIndicator();

			// draw shield
			if (hasShield) {
				float offset = 1.5;
				float shieldAlpha = shieldHp.x / 10 * alpha;
				canvas.noFill();
				canvas.stroke(colors.player[id],shieldAlpha);
				float weight = map(shieldHp.x,0,shieldHp.y,1,3);
				canvas.strokeWeight(weight);
				canvas.rect(cen.x,cen.y,siz.x * offset * drawScaleShield,siz.y * offset * drawScaleShield);
			}

			// draw the player cores
			canvas.noStroke();
			canvas.fill(colors.player[id],alpha);
			canvas.rect(cen.x,cen.y,sizCore.x * drawScale,sizCore.x * drawScale);

			// draw the cursor
			canvas.rect(cursorPos.x,cursorPos.y,cursorSiz.x * drawScale,cursorSiz.y * drawScale);
			
			// draw the item name on pickup
			if (showItem) drawItemName();

		} else if (!KILLED) drawRespawnIndicator();

		if (debugger.debugDraw) debugDraw();
	}

	void drawRespawnIndicator() {
		canvas.rectMode(CORNER);
		canvas.noFill();
		canvas.strokeWeight(CELL_SIZE / (CELL_SIZE / 3));
		canvas.stroke(colors.player[id],100);
		canvas.strokeCap(SQUARE);
		canvas.line(pos.x,pos.y,pos.x + siz.x/4,pos.y);
		canvas.line(pos.x + siz.x - siz.x/4,pos.y,pos.x + siz.x,pos.y);
		canvas.line(pos.x,pos.y,pos.x,pos.y + siz.x / 4);
		canvas.line(pos.x,pos.y + siz.x - siz.x / 4,pos.x,pos.y + siz.x);
		canvas.line(pos.x + siz.x,pos.y,pos.x + siz.x,pos.y + siz.x / 4);
		canvas.line(pos.x + siz.x,pos.y + siz.x - siz.x / 4,pos.x + siz.x,pos.y + siz.x);
		canvas.line(pos.x,pos.y + siz.x,pos.x + siz.x/4,pos.y + siz.x);
		canvas.line(pos.x + siz.x - siz.x / 4,pos.y + siz.x,pos.x + siz.x,pos.y + siz.x);
		canvas.noStroke();
		canvas.fill(colors.player[id],50);
		canvas.rect(pos.x + CELL_SIZE / 10, pos.y + CELL_SIZE / 10, siz.x - CELL_SIZE / 5, siz.x - CELL_SIZE / 5);
		canvas.textAlign(CENTER);
		canvas.textSize(CELL_SIZE / 1.5);
		canvas.fill(colors.player[id],200);
		canvas.pushMatrix();
		switch (id) {
			case 0:
				canvas.translate(pos.x + siz.x / 2,pos.y+siz.x / 2.8);
				canvas.rotate(radians(180)); break;
			case 1: 
				canvas.translate(pos.x + siz.x / 2,pos.y+siz.x / 1.5);
				canvas.rotate(radians(0)); break;
			case 2: 
				canvas.translate(pos.x + siz.x / 1.5,pos.y+siz.x / 2);
				canvas.rotate(radians(270)); break;
			case 3: 
				canvas.translate(pos.x + siz.x / 2.8,pos.y+siz.x / 2);
				canvas.rotate(radians(90)); break;
		}
		if (respawnTime > 0) canvas.text(ceil(respawnTime),0,0);
		else canvas.text("GO!",0,0);
		canvas.popMatrix();
	}

	void drawBoostIndicator() {
		// setup some temp variables for later adjustment
		float x1 = 0, y1 = 0, x2 = 0, y2 = 0, x3 = 0, y3 = 0;
		float lineDistance = siz.x / 8; 

		canvas.strokeWeight(CELL_SIZE / 16);
		canvas.pushMatrix();
		// set the drawing origin to the center of the player
		canvas.translate(cen.x,cen.y);

		// set the positions depending on the direction of the player
		if (dir.y == 0) {
			x1 = -siz.x / 2 * dir.x;
			y1 = -siz.x / 2;
			x2 = -siz.x / 2 * dir.x;
			y2 = siz.x / 2;
		} else if (dir.x == 0) {
			x1 = -siz.x / 2;
			y1 = -siz.x / 2 * dir.y;
			x2 = siz.x / 2;
			y2 = -siz.x / 2 * dir.y;
		} else {
			x1 = -siz.x / 2 * dir.x;
			y1 = 0;
			x2 = -siz.x / 2 * dir.x;
			y2 = -siz.x / 2 * dir.y;
			x3 = 0;
			y3 = -siz.x / 2 * dir.y;			
		} 

		for (int i=1;i<=3;i++) {
			canvas.stroke(colors.player[id],alpha / i);
			if (dir.x != 0) { x1 -= lineDistance * dir.x; x2 -= lineDistance * dir.x; x3 -= lineDistance * dir.x; }
			if (dir.y != 0) { y1 -= lineDistance * dir.y; y2 -= lineDistance * dir.y; y3 -= lineDistance * dir.y; }
			canvas.line(x1,y1,x2,y2);
			if (dir.x != 0 && dir.y != 0) canvas.line(x2,y2,x3,y3);
		}
		canvas.popMatrix();
	}

	void drawMultiShotIndicator() {

		float msMinSize = siz.x / 12;
		float msSpeed = 0.2;

		if (msIndicatorSize <= msMinSize || msIndicatorSize >= msMaxSize) msSpeed *= -1;
		msIndicatorSize += msSpeed;

		canvas.fill(colors.player[id],alpha);
		for (int xD=-1;xD<=1;xD++) {
			for (int yD=-1;yD<=1;yD++) {
			    if (xD == 0 && yD == 0) {}
			    else canvas.rect(cen.x + siz.x / 4 * xD,cen.y + siz.x / 4 * yD,msIndicatorSize,msIndicatorSize);
			}
		}
	}

	void boost() {
		// manages boosting and trail particles
		if (boosting && boostTime > 0) {

			boostTime -= 1 * dtInSeconds;
			
			// adds particles
			boolean createParticle = repeat(2);
			if (createParticle) {
				TrailParticle p = new TrailParticle(new PVector(cen.x,cen.y),siz.x,colors.player[id]);
				boostParticles.add(p);
			}

		} else {
			boosting = false;
			boostTime = boostDuration;
		}

		// update particles
		for (TrailParticle p : boostParticles) {
			if (p.remove) {
				boostParticles.remove(p);
				break;
			} else p.update();
		}
	}

	void drawItemName() {
		
		if (prevItem != currentItem) itemYPos = 0;

		prevItem = currentItem;
		
		canvas.pushMatrix();
		canvas.translate(cen.x,cen.y);

		if (TOP_VIEW) {
			switch (id) {
				case 0: canvas.rotate(radians(180)); break;
				case 1: canvas.rotate(radians(0)); break;
				case 2: canvas.rotate(radians(270)); break;
				case 3: canvas.rotate(radians(90)); break;
			}
		}
		
		canvas.textAlign(CENTER);
		canvas.textSize(CELL_SIZE);

		float itemYPosMax = -CELL_SIZE;
		float easing = 0.3;
		float itemDistance = itemYPosMax - itemYPos;
		float itemShowTime = 0.5;

		// set the text position
		if (itemYPos > itemYPosMax && abs(itemDistance) > 1) {
			// move the text up
			itemYPos += itemDistance * easing;

			// set the text transparency depending on the text position
			itemAlpha = (int)map(itemYPos,0,itemYPosMax,0,255);

			itemShowDuration = itemShowTime;
		} else {
			// let the text stand there for a little while
			if (itemShowDuration > 0) itemShowDuration -= 1 * dtInSeconds;
			else {
				// fade out the text
				int fadeOutSpeed = 70;
				if (itemAlpha > 0) itemAlpha -= fadeOutSpeed;
				else {
					itemYPos = 0;
					itemShowDuration = itemShowTime;
					showItem = false;
				}
			}
		} 

		// set the color and alpha
		canvas.fill(colors.player[id],itemAlpha);

		// draw the actual text
		canvas.text(currentItem,0,itemYPos);
		canvas.popMatrix();
	}

	void debugDraw() {
			// canvas.fill(255,255,255,255);
			// canvas.rect(pos.x,pos.y,siz.x / 4,siz.y / 4);
			// canvas.rect(cen.x,cen.y,siz.x / 4,siz.y / 4);
			// canvas.textSize(debugger.fontSize);
			// canvas.textAlign(CENTER);
			// canvas.fill(colors.player[id],255);
			// int playerID = id;
			// float textPosY = cen.y + siz.x + debugger.fontSize;
			// canvas.text("ID: " + id,cen.x,textPosY);
			// canvas.text("ALPHA: " + alpha,cen.x,textPosY+debugger.fontSize);
			// canvas.text("BOOSTING: " + strokeWidth,cen.x,textPosY+debugger.fontSize*2);
			// canvas.text("UP: " + upPressed,cen.x,textPosY+debugger.fontSize);
			// canvas.text("DOWN: " + downPressed,cen.x,textPosY+debugger.fontSize*2);
			// canvas.text("LEFT: " + leftPressed,cen.x,textPosY+debugger.fontSize*3);
			// canvas.text("RIGHT: " + rightPressed,cen.x,textPosY+debugger.fontSize*4);
	}

	float getVSpeed(float _acc, float _dec, float _maxSpeed) {
		// determine vertical speed
		if (input.north || ((boosting || wrapV) && dir.y == -1)) {
			if (speed.y > -_maxSpeed) speed.y -= _acc;
			else speed.y = -_maxSpeed;
		} else if (input.south || ((boosting || wrapV) && dir.y == 1)) {
			if (speed.y < _maxSpeed) speed.y += _acc;
			else speed.y = _maxSpeed;
		} else if (!wrapV) {
			if (abs(speed.y) > 0.1) speed.y *= _dec;
			else speed.y = 0;
		} 
		// return the vertical speed
		return speed.y * dtInSeconds;
	}

	float getHSpeed(float _acc, float _dec, float _maxSpeed) {
		// determine horizontal speed
		if (input.west || ((boosting || wrapH) && dir.x == -1)) {
			if (speed.x > -_maxSpeed) speed.x -= _acc;
			else speed.x = -_maxSpeed;
		} else if (input.east || ((boosting || wrapH) && dir.x == 1)) {
			if (speed.x < _maxSpeed) speed.x += _acc;
			else speed.x = _maxSpeed;
		} else if (!wrapH) {
			if (abs(speed.x) > 0.1) speed.x *= _dec;
			else speed.x = 0;
		}	
		// return the horizontal speed
		return speed.x * dtInSeconds;
	}

	void move() {
		// movement properties
		float maxSpeed = CELL_SIZE / 7;
		float acceleration = CELL_SIZE / 15;
		float deceleration = 0.1;			

		// change movement properties when boosting
		if (boosting) {
			maxSpeed = CELL_SIZE / 2;
			acceleration = 1.0;
		}

		if (boosting) {
			maxSpeed = 8.0;
			acceleration = 1.0;
		}

		getVSpeed(acceleration, deceleration, maxSpeed);
		getHSpeed(acceleration, deceleration, maxSpeed);

		//collision bools
		boolean collisionTop = false;
		boolean collisionBottom = false;
		boolean collisionLeft = false;
		boolean collisionRight = false;

		//check for collisions with other players
		for (Player p : oManager.players) {

			// only check for collisions when:
			// the id is different from the players id
			// when the other player isn't dead
			// when the player isn't in respawn mode
			// and when there isn't already a collision

			if (id != p.id && p.ALIVE && ALIVE) {
				if (!collisionTop) 		collisionTop = collision.checkBoxCollision(pos.x,pos.y - abs(speed.y),siz.x,siz.x,p.pos.x,p.pos.y,p.siz.x,p.siz.x);
				if (!collisionBottom)	collisionBottom = collision.checkBoxCollision(pos.x,pos.y + abs(speed.y),siz.x,siz.x,p.pos.x,p.pos.y,p.siz.x,p.siz.x);
				if (!collisionLeft)		collisionLeft = collision.checkBoxCollision(pos.x - abs(speed.x),pos.y,siz.x,siz.x,p.pos.x,p.pos.y,p.siz.x,p.siz.x);
				if (!collisionRight)	collisionRight = collision.checkBoxCollision(pos.x + abs(speed.x),pos.y,siz.x,siz.x,p.pos.x,p.pos.y,p.siz.x,p.siz.x);
 			}

		}

		// screenwrapping
		wrapH = checkWrapping("Horizontal");
		wrapV = checkWrapping("Vertical");
		if (wrapH) {
			input.east = false;
			input.west = false;
		}

		if (wrapV) {
			input.north = false;
			input.south = false;
		}

		//check for collisions with solids
		for (Solid s : oManager.solids) {
			if (wrapV) {
				if (!collisionTop)		collisionTop 		= collision.checkBoxCollision(pos.x,VIEW_HEIGHT - abs(speed.y),siz.x,siz.y,s.pos.x,s.pos.y,s.siz.x,s.siz.y);
				if (!collisionBottom) 	collisionBottom 	= collision.checkBoxCollision(pos.x,-siz.y + abs(speed.y),siz.x,siz.y,s.pos.x,s.pos.y,s.siz.x,s.siz.y);
				if (collisionTop || collisionBottom) dir.y *= -1;
			} else {
				if (!collisionTop)		collisionTop 	= collision.checkBoxCollision(pos.x,pos.y - abs(speed.y),siz.x,siz.x,s.pos.x,s.pos.y,s.siz.x,s.siz.y);
				if (!collisionBottom)	collisionBottom = collision.checkBoxCollision(pos.x,pos.y + abs(speed.y),siz.x,siz.x,s.pos.x,s.pos.y,s.siz.x,s.siz.y);
			}

			if (wrapH) {
				if (!collisionLeft)		collisionLeft = collision.checkBoxCollision(VIEW_WIDTH - abs(speed.x),pos.y,siz.x,siz.y,s.pos.x,s.pos.y,s.siz.x,s.siz.y);
				if (!collisionRight)	collisionRight = collision.checkBoxCollision(0 + abs(speed.x),pos.y,siz.x,siz.x,s.pos.x,s.pos.y,s.siz.x,s.siz.y);				
				if (collisionLeft || collisionRight) dir.x *= -1;
			} else {
				if (!collisionLeft)		collisionLeft = collision.checkBoxCollision(pos.x - abs(speed.x),pos.y,siz.x,siz.x,s.pos.x,s.pos.y,s.siz.x,s.siz.y);
				if (!collisionRight)	collisionRight = collision.checkBoxCollision(pos.x + abs(speed.x),pos.y,siz.x,siz.x,s.pos.x,s.pos.y,s.siz.x,s.siz.y);				
			}
		}

		// if there are no collisions set vertical speed
		if (speed.y <= 0 && !collisionTop) pos.y += speed.y;
		if (speed.y >= 0 && !collisionBottom) pos.y += speed.y;

		// if there are no collisions set horizontal speed
		if (speed.x <= 0 && !collisionLeft) pos.x += speed.x;
		if (speed.x >= 0 && !collisionRight) pos.x += speed.x;

		// screenwrapping
		if (pos.x > VIEW_WIDTH) pos.x = -siz.x;
		else if (pos.x + siz.x < 0) pos.x = VIEW_WIDTH;

		if (pos.y > VIEW_HEIGHT) pos.y = -siz.y;
		else if (pos.y + siz.y < 0) pos.y = VIEW_HEIGHT;
	}

	boolean checkWrapping(String _direction) {
		// checks if the player is wrapping around the screen
		boolean wrapping = false;

		if (_direction == "Horizontal") wrapping = (pos.x + siz.x > VIEW_WIDTH || pos.x < 0) ? true : false;
		if (_direction == "Vertical") wrapping = (pos.y + siz.y > VIEW_HEIGHT || pos.y < 0) ? true : false;

		return wrapping;
	}

	void face() {
		// this method determines which direction the player is facing and sets the player cursor appropriately
		if (input.north) {
			dir.y = -1;
			if (!input.west && !input.east) dir.x = 0;
		}
		else if (input.south) {
			dir.y = 1;
			if (!input.west && !input.east) dir.x = 0;
		}
		
		if (input.west) {
			dir.x = -1;
			if (!input.north && !input.south) dir.y = 0;
		}
		else if (input.east) {
			dir.x = 1;
			if (!input.north && !input.south) dir.y = 0;
		}

		//evaluate the position of the cursor depending on the player direction
		if (dir.y > 0) cursorPos.y = pos.y + siz.x;
		else if (dir.y < 0) cursorPos.y = pos.y;
		else cursorPos.y = pos.y + siz.x / 2;

		if (dir.x > 0) cursorPos.x = pos.x + siz.x;
		else if (dir.x < 0) cursorPos.x = pos.x;
		else cursorPos.x = pos.x + siz.x / 2;
	}

	void shoot() {
		//shoot bullets!
		if (input.shootReleased) {
			
		    oManager.addBullet(id,cursorPos,dir,charge);
		    shot01.trigger();
		    shots++;
			charge = minCharge;
			input.shootReleased = false;
			chargeDelay = initChargeDelay;
			shootDelayTime = shootDelayDuration;
		
		} else if (input.shootWasPressed) {

			if (chargeDelay > 0) chargeDelay--;
			else {
				if (charge < maxCharge) charge++;
				else charge = maxCharge;
			}
		
		}
	}

	void hit() {
		//go through each existing bullet and check if the player collides with any of them
		for (Bullet b : oManager.bullets) {

			// skip the players own bullets
			if (id == b.id) continue;

			//only check collisions when the player isn't dead
			if (ALIVE) hit = collision.checkBoxCollision(pos.x,pos.y,siz.x,siz.x,b.pos.x,b.pos.y,b.siz.x,b.siz.y);

			// if the player was hit by a bullet
			if (hit) {

				Player p = oManager.players[b.id];				// get the id of the shooter
				
				if (b.damage != 0) {
					screenShake.shake(1,0.2);

					if (!hasShield) {
						drawScale = 1.5;
						hp.x -= b.damage;
					} else {
						drawScaleShield = 1.5;
						shieldHp.x -= b.damage;
					}
				}
				
				b.damage = 0;									// set the bullet damage to 0 (used to determine if it still can do damage)
				if (hp.x <= 0) p.kills++;						// add the shooters killcount if the bullet killed the target
			}

		}

		hit = false;
	}

	void die() {
		KILLED = true;
		die01.trigger();
		screenShake.shake(7,1.2);
		deaths++;
		if (respawnDuration != 0) respawnDuration *= respawnDurationMultiplier;
		else respawnDuration = respawnDurationMultiplier;
		respawnTime = respawnDuration;		
		oManager.activePlayers--;
	}

	void knockBack(PVector dir) {
		// knocks the player back when hit
		int knockBackStrength = 5;

		// speed.x = knockBackStrength * _dir.x * dtInSeconds; 
		// speed.y = knockBackStrength * _dir.y * dtInSeconds; 

		//play a sound
		hurt01.trigger();

		knockBack = true;		// this doesn't do anything but can be used later if needed
	}

	void spawn() {
		// respawns the player if possible
		boolean canSpawn = checkSpawnKill();

		if (canSpawn) {
			// respawn the player and reset it's properties
			ALIVE = true;
			INVINCIBLE = true;
			spawnedOnce = true;
			hp.x = hp.y;
			alpha = 255;
			drawScale = initialDrawScale;
			spawn01.trigger();
			oManager.activePlayers++;
		}
	}

	boolean checkSpawnKill() {
		boolean canSpawn = true;
		boolean spawnKill = false;

		//check for collisions with other players and kill them when spawning on top of them
		for (Player p : oManager.players) {
			// skip own player id and dead players
			if (id == p.id || !p.ALIVE) continue;

			spawnKill = collision.checkBoxCollision(pos.x,pos.y,siz.x,siz.x,p.pos.x,p.pos.y,p.siz.x,p.siz.x);
				
 			if (spawnKill) {
 				if (!p.INVINCIBLE) p.hp.x -= p.hp.x; 					
 				else canSpawn = false;
 			}
		}
		return canSpawn;
	}
}