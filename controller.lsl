#define USE_LAZY_LISTS
#include "channels.h"

list treeTypes = ["Winter Tree", "Summer Tree"];
integer replaceType;
integer dialogListener;
integer treeCount;
list treeList;
vector homePos;

default
{
  state_entry() {
    integer treesInInventory = llGetListLength(treeList);
    if (treesInInventory > 0) {
      llSetText("TreeReplacer Controller\nTrees in inventory: "+(string)treesInInventory+"\nClick for menu", <255,255,255>, 1);
    } else {
      llSetText("TreeReplacer Controller\nClick for menu", <255,255,255>, 1);
    }
  }

  touch_start(integer index) {
    key    avatarKey  = llDetectedKey(0);
    string avatarName =  llDetectedName(0);
    llDialog(avatarKey,"TreeReplacer Command", ["Inventory","Winter Replace","Summer Replace","Delete All"],DIALOG_CHANNEL);
    dialogListener = llListen(DIALOG_CHANNEL, "", avatarKey, "");
    llSetTimerEvent(60.0);
  }

  listen(integer channel, string name, key id, string message) {
    llListenRemove(dialogListener);
    llSetTimerEvent(0.0);
    if (message == "Inventory") {
      llOwnerSay("Collecting tree inventory.");
      state inventory;
    }
    if (message == "Summer Replace") {
      replaceType = 1;
      state replace;
    }
    if (message == "Winter Replace") {
      replaceType = 0;
      state replace;
    }
    if (message == "Delete All") {
      state deleteAll;
    }
  }

  timer() {
    llListenRemove(dialogListener);
    llOwnerSay("Dialog timeout.");
    llSetTimerEvent(0.0);
  }
}

state deleteAll {
  state_entry() {
    llSetText("Replace Mode", COLOR_WHITE, OPAQUE);
    llOwnerSay("Deleting All Trees!");
    if (llGetListLength(treeList) == 0) {
      llOwnerSay("You must run inventory first.");
      state default;
    }

    integer i;
    for (i = 0; i < llGetListLength(treeList); i++) {
      string treeJson = (string)treeList[i];
      key treeKey = (key)llJsonGetValue(treeJson, [0]);
      llRegionSay(COMM_CHANNEL,"die "+(string)treeKey);
    }
    llOwnerSay("Done!");
    treeList = [];
    state default;
  }
  state_exit() {
    llSetText("", ZERO_VECTOR, 0);
  }
}

state replace {
  state_entry() {
    llSetText("Replace Mode", COLOR_WHITE, OPAQUE);
    llOwnerSay("Replacing trees.");
    if (llGetListLength(treeList) == 0) {
      llOwnerSay("You must run inventory first.");
      state default;
    }

    integer i;
    // remember how to get home
    homePos = llGetPos();
    llMessageLinked(LINK_THIS, 0, "particle on", "");
    for (i = 0; i < llGetListLength(treeList); i++) {

      string treeJson = (string)treeList[i];
      key treeKey = (key)llJsonGetValue(treeJson, [0]);
      vector treePos = (vector)llJsonGetValue(treeJson,[1]);
      rotation treeRot = (rotation)llJsonGetValue(treeJson, [2]);
      string treeOldName = llJsonGetValue(treeJson, [3]);

      // fly to target tree, since llRezAtRoot has a 10m range
      if (llSetRegionPos(treePos + <0,0,1>)) {
        llSleep(0.25);
        // replace it
        llRezAtRoot((string)treeTypes[replaceType], treePos, ZERO_VECTOR, treeRot, 0);
        //llOwnerSay("asking old tree to die!");
        llRegionSay(COMM_CHANNEL,"die "+(string)treeKey);

      } else {
        llOwnerSay("unable to warp to tree #"+(string)i+" ("+treeOldName+") at "+(string)treePos+", skipping it.");
      }
    }
    // fly home
    llSetRegionPos(homePos);
    llMessageLinked(LINK_THIS, 0, "particle off", "");
    llOwnerSay("Done!");
    treeList = [];
    state default;
  }

  state_exit() {
    llSetText("", ZERO_VECTOR, 0);
  }
}

state inventory {
  state_entry() {
    llSetText("Inventory Mode", COLOR_WHITE, OPAQUE);
    treeCount = 0;
    treeList = [];
    llListen(COMM_CHANNEL, "", NULL_KEY, "");
    llRegionSay(COMM_CHANNEL,"inventory");
    llOwnerSay("Please wait (5 seconds)");
    llSetTimerEvent(5);
  }

  listen(integer channel, string name, key id, string message) {
    //llOwnerSay("got message from "+(string)id+": "+message);
    llSetText("Inventory Mode\nTrees found: "+(string)(treeCount+1), COLOR_WHITE, OPAQUE);
    treeList += message;
    treeCount++;
  }

  timer() {
    llSetTimerEvent(0.0);
  //  llOwnerSay("Done! Found "+(string)treeCount+" trees.");
  //  llOwnerSay("Treelist: "+(string)treeList);
    llOwnerSay("Discovered "+(string)llGetListLength(treeList)+" trees.");
    state default;
  }

  state_exit() {
    llSetText("", ZERO_VECTOR, 0);
  }
}
