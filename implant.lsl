#define USE_LAZY_LISTS
#include "channels.h"

default
{
  state_entry()
  {
    llListen(COMM_CHANNEL, "", NULL_KEY, "");
  }

  listen(integer channel, string name, key id, string message)
  {
    if (llGetOwnerKey(id) == llGetOwner()) {
      if (message == "inventory") {
        string json = llList2Json(JSON_ARRAY, [(string)llGetKey(), (string)llGetRootPosition(), llGetRootRotation(), llGetLinkName(LINK_ROOT)]);
        llRegionSay(COMM_CHANNEL, json);
      }

      if (message == ("die "+(string)llGetKey())) {
        // the object sending the command must be owned
        // by the same person as this object
        llDie();
      }
    }
  }
}
