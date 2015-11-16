#define USE_LAZY_LISTS
#include "channels.h"

string replaceTreeName;
string newTreeName;
integer dialogListener;
integer treeCount;
list treeList;
list uniqueTrees;
list newTreeList;
vector homePos;
key avatarKey;
string avatarName;


list listUnique( list lAll ) {
    integer i;
    list lFiltered = llList2List(lAll, 0, 0);
    integer iAll = llGetListLength( lAll );
    for (i = 1; i < iAll; ++i) {
        if ( llListFindList(lFiltered, llList2List(lAll, i, i) ) == -1 ) {
            lFiltered += llList2List(lAll, i, i);
        }
    }
    return lFiltered;
}

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
    avatarKey  = llDetectedKey(0);
    avatarName =  llDetectedName(0);

    integer treesInInventory = llGetListLength(treeList);
    uniqueTrees = [];

    if (treesInInventory > 0) {
        // get a list of the unique trees
        integer i;
        for (i = 0; i < llGetListLength(treeList); i++) {
          string treeJson = (string)treeList[i];
          string treeOldName = llJsonGetValue(treeJson, [3]);
          uniqueTrees += treeOldName;
        }
        uniqueTrees = listUnique(uniqueTrees);
        llOwnerSay("Choose the type of tree to replace:");

    }

    list dialogButtons = ["Inventory"];
    integer i;
    for (i = 0; i < llGetListLength(uniqueTrees); i++) {
        dialogButtons += "Tree "+(string)i;
        llOwnerSay("Old Tree ["+(string)i+"]: " + llList2String(uniqueTrees, i));
    }

    llDialog(avatarKey,"Replace trees", dialogButtons ,DIALOG_CHANNEL);
    dialogListener = llListen(DIALOG_CHANNEL, "", avatarKey, "");
    llSetTimerEvent(60.0);
  }

  listen(integer channel, string name, key id, string message) {
    llListenRemove(dialogListener);
    llSetTimerEvent(0.0);
    if (llSubStringIndex(message,"Tree ") == 0) {
      // this is a replace command
      string replaceTreeIndex = llGetSubString(message,llStringLength("Tree "),-1);
      replaceTreeName = llList2String(uniqueTrees,(integer)replaceTreeIndex);
      state replaceDialog;
    }
    else if (message == "Inventory") {
      llOwnerSay("Collecting tree inventory.");
      state inventory;
    }
    else if (message == "Delete All") {
      state deleteAll;
    } else {
      llOwnerSay("wat?");
    }
  }

  timer() {
    llListenRemove(dialogListener);
    llOwnerSay("Dialog timeout.");
    llSetTimerEvent(0.0);
  }
}

state replaceDialog {
  state_entry() {
    // get the list of objects in my inventory... they are the "to" list
    list  dialogButtons;
    llOwnerSay("Choose a new tree:");
    newTreeList = [];
    integer numObjects = llGetInventoryNumber(INVENTORY_OBJECT);
    integer i;
    for (i = 0; i < numObjects; i++) {
        string objectName = llGetInventoryName(INVENTORY_OBJECT, i);
        newTreeList += objectName;
        dialogButtons += "Tree "+(string)i;
        llOwnerSay("New Tree ["+(string)i+"]: "+objectName);
    }

    llDialog(avatarKey,"Replace with", dialogButtons ,DIALOG_CHANNEL);
    dialogListener = llListen(DIALOG_CHANNEL, "", avatarKey, "");
    llSetTimerEvent(60.0);
  }

  listen(integer channel, string name, key id, string message) {
    llOwnerSay("got message: "+message);
    if (llSubStringIndex(message,"Tree ") == 0) {
      string newTreeIndex = llGetSubString(message,llStringLength("Tree "),-1);
      newTreeName = llList2String(newTreeList,(integer)newTreeIndex);
      state replace;
    } else {
      llOwnerSay("wat!?");
      state default;
    }
  }

  timer() {
    llListenRemove(dialogListener);
    llOwnerSay("Dialog timeout.");
    llSetTimerEvent(0.0);
    state default;
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

      // check to see if the tree is the right type
      if (treeOldName == replaceTreeName) {
      // fly to target tree, since llRezAtRoot has a 10m range
        if (llSetRegionPos(treePos + <0,0,1>)) {
          llSleep(0.25);
          // replace it
          llRezAtRoot(newTreeName, treePos, ZERO_VECTOR, treeRot, 0);
          llRegionSay(COMM_CHANNEL,"die "+(string)treeKey);
        } else {
          llOwnerSay("unable to warp to tree #"+(string)i+" ("+treeOldName+") at "+(string)treePos+", skipping it.");
        }
      } else {
        // llOwnerSay("skipping tree "+treeOldName+" at "+(string)treePos);
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
