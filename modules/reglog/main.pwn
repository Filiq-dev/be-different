
function MySQL_Init() {

    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_DB, MYSQL_PASS);
    if(mysql_errno(g_SQL) != 0){
        print("[MySQL] connection failed. Server is shutting down.");
        SendRconCommand("exit");
        return true;
    }

    print("[MySQL] connection is successful.");

    SetupPlayerTable();

    return true;
}

function MySQL_Exit() {
    foreach(new i : Players) {
        if(IsPlayerConnected(i))
          OnPlayerDisconnect(i, 1);
    }

    mysql_close(g_SQL);
    print("[MySQL] Successfully disconnected from database!");

    return true;
}

function MySQL_Check(playerid, bool:cases) {

    switch(cases) {
        case true: {
            UpdatePlayerData(playerid);

            PlayerData[playerid][IsLoggedIn] = false;

            static const empty_player[pData];
            PlayerData[playerid] = empty_player;
        }
        case false: {
            GetPlayerName(playerid, PlayerData[playerid][pName], MAX_PLAYER_NAME);

            gQuery[0] = (EOS);
            mysql_format(g_SQL, gQuery, 100, "SELECT * FROM `players` WHERE `username` = '%e' LIMIT 1", PlayerData[playerid][pName]);
            mysql_tquery(g_SQL, gQuery, "OnPlayerDataLoaded", "d", playerid);
        }
    }

    return true;
}

function OnPlayerDataLoaded(playerid) {
    if(cache_num_rows() > 0) {
      	cache_get_field_content(0, "password", PlayerData[playerid][pPassword], 65);
      	cache_get_field_content(0, "salt", PlayerData[playerid][pSalt], 17);

        gString[0] = (EOS);
      	format(gString, 120, "This account (%s) is registered. Please login by entering your password in the field below:", GetName(playerid));
      	ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", gString, "Login", "Abort");
    }
    else {
        gString[0] = (EOS);
      	format(gString, 120, "Welcome %s, you can register by entering your password in the field below:", GetName(playerid));
      	ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", gString, "Register", "Abort");
    }

    return true;
}

function Dialog_RegLog(playerid, bool:cases, response, inputtext[]) {
    switch(cases) {
        case true: {
            if (!response) return Kick(playerid);
            if (strlen(inputtext) <= 5) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", "Your password must be longer than 5 characters!\nPlease enter your password in the field below:", "Register", "Abort");

            for (new i = 0; i < 16; i++) PlayerData[playerid][pSalt][i] = random(94) + 33;
            SHA256_PassHash(inputtext, PlayerData[playerid][pSalt], PlayerData[playerid][pPassword], 65);

            gQuery[0] = (EOS);
            mysql_format(g_SQL, gQuery, 256, "INSERT INTO `players` (`username`, `password`, `salt`) VALUES ('%e', '%s', '%e')", PlayerData[playerid][pName], PlayerData[playerid][pPassword], PlayerData[playerid][pSalt]);
            mysql_tquery(g_SQL, gQuery, "OnPlayerRegister", "d", playerid);
        }
        case false: {
            if(!response) return Kick(playerid);

            new hashed_pass[65];
            SHA256_PassHash(inputtext, PlayerData[playerid][pSalt], hashed_pass, 65);

            gQuery[0] = (EOS);
            mysql_format(g_SQL, gQuery, sizeof(gQuery), "SELECT * FROM `players` WHERE `username`='%e' AND `password`='%e'", GetName(playerid), hashed_pass);
            mysql_tquery(g_SQL, gQuery, "AssignPlayerData", "i", playerid);
        }
    }

    return true;
}

function OnPlayerRegister(playerid) {
    PlayerData[playerid][pID] = cache_insert_id();

    ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "Registration", "Account successfully registered, you have been automatically logged in.", "Okay", "");

    PlayerData[playerid][IsLoggedIn] = true;

    GivePlayerCash(playerid, 100000);

    SpawnPlayer(playerid);

    return true;
}

function AssignPlayerData(playerid) {
    if(cache_num_rows() > 0) {
      PlayerData[playerid][pID] = cache_get_field_content_int(0, "id");
      PlayerData[playerid][pAdmin] = cache_get_field_content_int(0, "adminlevel");
      PlayerData[playerid][pHelper] = cache_get_field_content_int(0, "helperlevel");
      PlayerData[playerid][pMoney][0] = cache_get_field_content_int(0, "money");
      PlayerData[playerid][pMoney][1] = cache_get_field_content_int(0, "money2");
      PlayerData[playerid][pMoneyB][0] = cache_get_field_content_int(0, "moneyb");
      PlayerData[playerid][pMoneyB][1] = cache_get_field_content_int(0, "moneyb2");

      new money = (PlayerData[playerid][pMoney][0] + PlayerData[playerid][pMoney][1]);
      SetPlayerCash(playerid, money);

      SendClientMessage(playerid, -1, "You have been successfully logged in.");

      PlayerData[playerid][IsLoggedIn] = true;

      SpawnPlayer(playerid);

    } else ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Wrong password!\nPlease enter your password in the field below:", "Login", "Abort");
}

function UpdatePlayerData(playerid) {
    if(PlayerData[playerid][IsLoggedIn] == false) return false;

    gQuery[0] = (EOS);
  	mysql_format(g_SQL, gQuery, 256, "UPDATE `players` SET `money` = '%d', `money2` = '%d', `moneyb` = '%d', `moneyb2` = '%d'  WHERE `id` = '%d' LIMIT 1", PlayerData[playerid][pMoney][0], PlayerData[playerid][pMoney][1], PlayerData[playerid][pMoneyB][0], PlayerData[playerid][pMoneyB][1],  PlayerData[playerid][pID]);
  	mysql_tquery(g_SQL, gQuery);

    return true;
}

SetupPlayerTable() {
    mysql_tquery(g_SQL, "CREATE TABLE IF NOT EXISTS `players` (`id` int(11) NOT NULL AUTO_INCREMENT,`username` varchar(24) NOT NULL,`password` char(64) NOT NULL,`salt` char(16) NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `username` (`username`))");
    return true;
}
